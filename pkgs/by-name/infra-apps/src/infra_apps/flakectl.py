"""Build, deploy, and update the hosts and packages of this flake."""

import argparse
import concurrent.futures
import functools
import getpass
import itertools
import json
import os
import pwd
import re
import shlex
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import urllib.parse
from argparse import _SubParsersAction
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass, fields
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import FunctionType
from typing import Any

import obstore
from obstore.exceptions import BaseError
from obstore.store import S3Store

from infra_apps.apptools import (
    CommandError,
    Error,
    HelpFormatter,
    add_command,
    complete,
    entrypoint,
    run,
    run_json,
    run_nul,
)

# Host that `access-tokens` entries are keyed by.
GITHUB_HOST = "github.com"

GITHUB_ACTIONS = os.environ.get("GITHUB_ACTIONS") == "true"

# the Actions log renders colors although stderr is a pipe there
COLOR = GITHUB_ACTIONS or sys.stderr.isatty()

# Flags passed to every `nix` invocation.
# The settings of every nix that runs, also within the tools that flakectl runs.
NIX_CONFIG = "extra-experimental-features = nix-command flakes"

# The store directory and hash of a store path, which logs leave out.
STORE_PATH_PREFIX = re.compile(r"/nix/store/[0-9a-z]{32}-")


TARGET_APPLY = "builtins.mapAttrs (_: drv: drv.drvPath)"

# The expression listing the update scripts of the packages, see `update_scripts_args`.
UPDATE_SCRIPTS = str(Path(__file__).with_name("update_scripts.nix"))

# Whether CI builds a derivation, following Hydra's `meta.hydraPlatforms`. The
# flake's `lib.isHydraTarget` splits `checks` by the same rule. Only `system` and
# `meta` are read, so a derivation that is not built is not forced either.
IS_HYDRA_TARGET = (
    "drv: builtins.elem drv.system (drv.meta.hydraPlatforms or [ drv.system ])"
)

# The attributes of `set` whose value satisfies `pred`.
FILTER_ATTRS = (
    "pred: set: builtins.removeAttrs set"
    " (builtins.filter (name: !pred set.${name}) (builtins.attrNames set))"
)

# `check build`: the targets of one system's `checks` that CI builds.
BUILD_SELECT = f"""
let
  isHydraTarget = {IS_HYDRA_TARGET};
  filterAttrs = {FILTER_ATTRS};
in
filterAttrs isHydraTarget
"""

# `check flake`: every derivation `nix flake check` evaluates that `check build`
# does not, so that both jobs together cover the flake exactly once.
EVAL_SELECT = f"""
flake:
let
  inherit (flake) outputs;
  isHydraTarget = {IS_HYDRA_TARGET};
  filterAttrs = {FILTER_ATTRS};
  built = builtins.mapAttrs (_: filterAttrs isHydraTarget) outputs.checks;
  notBuilt = system: set: builtins.removeAttrs set (builtins.attrNames (built.${{system}} or {{ }}));
in
{{
  checks = builtins.mapAttrs notBuilt outputs.checks;
  packages = builtins.mapAttrs notBuilt outputs.packages;
  devShells = outputs.devShells;
}}
"""

# `cache gc`: the store derivations of the targets that `check build` builds
# and pushes, across all systems.
ROOTS_APPLY = f"""
systems:
let
  select = {BUILD_SELECT};
in
builtins.concatMap (set: builtins.attrValues ({TARGET_APPLY} (select set))) (
  builtins.attrValues systems
)
"""

# The outputs of `nix flake check` that are no derivations. `overlays.default` is
# left out, since every package set applies it, and `.#overlays` would select
# `legacyPackages.<system>.overlays` instead.
APPS_APPLY = "builtins.mapAttrs (_: builtins.mapAttrs (_: app: app.program))"

# nix-eval-jobs bounds shared by `check flake` and `check build`. A worker past
# its share is restarted, so peak memory stays at `workers * max_memory_size` MiB.
# One worker of 6 GiB fits any host as well as the largest single configuration
# (about 4.7 GB).
EVAL_WORKERS = 1
EVAL_MAX_MEMORY_SIZE = 6144

# GKD_CONTROL_OP_CHANGE and GKD_CONTROL_RESULT_OK of the gnome-keyring control socket.
KEYRING_OP_CHANGE = 2
KEYRING_RESULT_OK = 0


@dataclass(frozen=True, slots=True)
class BuildTarget:
    """A flake attribute resolved to its store derivation."""

    drv_path: str

    @property
    def installable(self) -> str:
        """Address the store derivation, so that building needs no evaluator."""
        return f"{self.drv_path}^*"


@dataclass(frozen=True, slots=True)
class Config:
    """The global options, which every command shares."""

    flake: str
    impure_attr: str | None
    build_path: str | None
    hash_path: str | None
    update_path: str | None
    cache: str | None
    max_workers: int
    is_worktree: bool

    def require_worktree(self) -> None:
        """Refuse to edit a checkout that is not the flake we were resolved from."""
        if not self.is_worktree:
            raise Error("Not this flake's working copy, run from a checkout.")


def log_cmd(cmd: list[str]) -> None:
    """Echo `cmd` to stderr in short.

    `nix run <flake>#<package> --` shows as the package alone, and store paths as
    their names.
    """
    if installable := program_installable(cmd):
        cmd = [installable.rpartition("#")[2], *cmd[4:]]

    print(
        shlex.join(STORE_PATH_PREFIX.sub("", arg) for arg in cmd),
        file=sys.stderr,
    )


def run_logged(cmd: list[str], *, check: bool = True) -> int:
    """Log `cmd`, run it with its output on the terminal, and return its exit code.

    Pass `check=False` for a command whose failure is not fatal.
    """
    log_cmd(cmd)

    try:
        run(*cmd, output=False)
    except CommandError as error:
        if installable := program_installable(cmd):
            require_package(installable)

        if check:
            raise

        return error.exit_code

    return 0


def flake_program(cfg: Config, package: str) -> list[str]:
    """Run the main program of the flake's `package`.

    nix and git come from the host, every other tool is pinned by the flake just
    like the configurations it acts on, and only fetched by the commands using
    it. Only the commands editing a checkout need git, so the others also work on
    a fresh machine that has nothing but Nix.
    """
    return ["nix", "run", f"{cfg.flake}#{package}", "--"]


def program_installable(cmd: Sequence[str]) -> str | None:
    """The installable of a `flake_program` command, None for any other."""
    return cmd[2] if cmd[:2] == ["nix", "run"] and cmd[3:4] == ["--"] else None


def require_package(installable: str) -> None:
    """Explain a failed `installable` by the package its flake lacks, if that is the cause.

    Only probed after a failure, so that a successful run costs no extra evaluation.
    """
    try:
        nix_eval_json(f"{installable}.type")
    except CommandError as error:
        if "does not provide attribute" in error.stderr:
            flake, _, package = installable.rpartition("#")

            raise Error(
                f"{flake} has no package {package}, import the flake-parts module"
                " `modules.flake.flakectl` of infra to provide it."
            ) from None


def flake_ref(flake: str, attr_path: str, name: str) -> str:
    """Installable for `name` within `attr_path`.

    The name is quoted so a dot in it stays one attribute, and the leading dot
    makes `attr_path` absolute, so nix neither looks it up in `packages.<system>`
    first nor builds a same-named package instead."""
    return f'{flake}#.{attr_path}."{name}"'


def nix_eval_json(*args: str) -> Any:
    """Evaluate a nix expression to JSON and parse it."""
    return run_json("nix", "eval", "--json", *args, capture=True)


def nix_eval_targets(installable: str) -> dict[str, BuildTarget]:
    """Evaluate `installable` and assert it returns `{name: derivation}`."""
    entries = nix_eval_json(installable, "--apply", TARGET_APPLY)

    if not isinstance(entries, dict) or not all(
        isinstance(drv, str) and drv.endswith(".drv") for drv in entries.values()
    ):
        raise Error(f"nix eval {installable} did not return an attrset of derivations")

    return {name: BuildTarget(drv_path=drv) for name, drv in entries.items()}


def build_targets(targets: Mapping[str, BuildTarget], *, check: bool = True) -> int:
    """Build the store derivations of `targets` without evaluating again."""
    if not targets:
        return 0

    refs = [target.installable for target in targets.values()]

    return run_logged(["nix", "build", "--no-link", *refs], check=check)


def rebuild(
    cfg: Config, extra_args: Sequence[str], operation: str, name: str | None
) -> None:
    """Build and apply a darwin / nixos / home-manager configuration."""
    uname = os.uname()
    node = uname.nodename.lower()
    kernel = uname.sysname.lower()
    user = getpass.getuser().lower()
    is_home = user != "root"

    if not name:
        name = f"{user}@{node}" if is_home else node

    if is_home:
        builder, attr = "home-manager", "homeConfigurations"
    elif kernel == "darwin":
        builder, attr = "darwin-rebuild", "darwinConfigurations"
    else:
        builder, attr = "nixos-rebuild-ng", "nixosConfigurations"

    impure = (
        ["--impure"]
        if cfg.impure_attr
        and nix_eval_json(f"{flake_ref(cfg.flake, attr, name)}.{cfg.impure_attr}")
        else []
    )
    run_flake_tool(cfg, extra_args, builder, name, operation, *impure)


def run_flake_tool(
    cfg: Config, extra_args: Sequence[str], package: str, name: str, *args: str
) -> None:
    """Run the flake's `package` on its configuration `name`, extra args last."""
    run_logged(
        [
            *flake_program(cfg, package),
            *args,
            "--flake",
            f"{cfg.flake}#{name}",
            *extra_args,
        ]
    )


def disko(cfg: Config, extra_args: Sequence[str], machine: str) -> None:
    """Partition, format, and mount the disks of `machine`."""
    run_flake_tool(cfg, extra_args, "disko", machine)


def install_disko(cfg: Config, extra_args: Sequence[str], machine: str) -> None:
    """Partition the disks of `machine` and install it in one go."""
    run_flake_tool(cfg, extra_args, "disko-install", machine)


def install_nixos(cfg: Config, extra_args: Sequence[str], machine: str) -> None:
    """Install `machine` onto the disks that `disko` mounted."""
    run_flake_tool(
        cfg,
        extra_args,
        "nixos-install",
        machine,
        "--no-channel-copy",
        "--no-root-password",
    )


def set_root_owned(path: Path, mode: int) -> None:
    """Hand `path` to root with `mode`, out of reach of every other user."""
    path.chmod(mode)
    shutil.chown(path, 0, 0)


def prompt_secret(prompt: str) -> str:
    """Prompt for a hidden value until it is typed the same way twice."""
    while True:
        value = getpass.getpass(f"{prompt}: ")

        if value == getpass.getpass("Repeat for confirmation: "):
            return value

        print("Error: The two entered values do not match.", file=sys.stderr)


def keyring_control(user: str) -> Path | None:
    """Control socket of the gnome-keyring daemon in a running session of `user`."""
    try:
        uid = pwd.getpwnam(user).pw_uid
    except KeyError:
        return None

    path = Path(f"/run/user/{uid}/keyring/control")
    return path if path.is_socket() else None


def change_keyring(control: Path, original: str, password: str) -> None:
    """Re-encrypt the login keyring from `original` to `password`.

    Sends the request of pam_gnome_keyring on a password change, see
    `gkd_control_change_lock` in gnome-keyring's `daemon/control/gkd-control-client.c`:
    a credential byte, then a packet of big-endian u32 length, op,
    and length-prefixed strings. The reply is the u32 length and result.
    """
    fields = b"".join(
        struct.pack(">I", len(field)) + field
        for field in (original.encode(), password.encode())
    )
    packet = struct.pack(">II", 8 + len(fields), KEYRING_OP_CHANGE) + fields

    with socket.socket(socket.AF_UNIX) as sock:
        # The daemon only serves peers whose uid at connect time matches its own.
        os.seteuid(control.stat().st_uid)

        try:
            sock.connect(str(control))
        finally:
            os.seteuid(0)

        sock.sendall(b"\0" + packet)
        reply = sock.recv(8, socket.MSG_WAITALL)

    if reply != struct.pack(">II", 8, KEYRING_RESULT_OK):
        raise Error("The keyring rejected the current password.")


def passwd(cfg: Config, machine: str, user: str, root: Path) -> None:
    """Hash a prompted password into the `hashedPasswordFile` of `user` on `machine`.

    The path comes from the NixOS configuration, so it cannot drift from the one
    the system reads. Pass `--root /mnt` for an installer target.
    """
    # Checked up front rather than left to the chown: nobody should type a
    # password only to be told afterwards that it could not be stored.
    if os.geteuid() != 0:
        raise Error("passwd must run as root.")

    if not root.is_dir():
        raise Error(f"Root {root} is no directory.")

    # Nix itself reports a missing machine or user, suggesting similar names.
    target: str | None = nix_eval_json(
        f"{flake_ref(cfg.flake, 'nixosConfigurations', machine)}"
        f'.config.users.users."{user}".hashedPasswordFile',
    )

    if target is None:
        raise Error(f"{machine} sets no hashedPasswordFile for {user}.")

    path = Path(target)

    if not path.is_absolute() or path.is_relative_to("/nix/store"):
        raise Error(f"Refusing to write {path}, not a mutable path.")

    file = root / path.relative_to("/")
    installable = f"{cfg.flake}#mkpasswd"
    # Fetched up front, so that hashing takes no wait once the password is typed,
    # and the later `nix run` resolves it from the evaluation cache.
    try:
        run("nix", "build", "--no-link", installable, capture=True)
    except CommandError:
        require_package(installable)
        raise

    print(f"Setting the password of {user}@{machine} in {file}", file=sys.stderr)
    # A live session on this host keeps the login keyring in step,
    # which needs its current password. Host names default to the machine names.
    local = root == Path("/") and machine == socket.gethostname()
    control = keyring_control(user) if local else None
    original = getpass.getpass("Current password: ") if control else ""
    password = prompt_secret("New password")

    if not password:
        raise Error("No password supplied.")

    # Before the hash, so that a mistyped current password changes nothing.
    if control:
        change_keyring(control, original, password)
        print(f"Re-encrypted the login keyring of {user}.", file=sys.stderr)

    # Hand the password over on stdin; argv is world-readable via /proc.
    hashed = run(
        *flake_program(cfg, "mkpasswd"),
        "--method=yescrypt",
        "--stdin",
        stdin=password,
        capture=True,
    ).strip()
    # Create missing ancestors one at a time: mkdir's mode is masked by the
    # caller's umask, and a setgid parent would hand the new directory its group.
    for directory in reversed(file.parents):
        if not directory.is_dir():
            directory.mkdir()
            set_root_owned(directory, 0o755)

    # Settle ownership while the file is still empty. Running as root only covers
    # a file we create here; chown is what stops an existing one, say from an
    # /etc/nixos owned by the user, holding the hash as theirs.
    file.touch()
    set_root_owned(file, 0o600)
    file.write_text(f"{hashed}\n")
    print(f"Wrote {file}, rebuild the configuration to apply.", file=sys.stderr)


@functools.cache
def access_tokens() -> Mapping[str, str]:
    """The credentials nix itself uses to fetch inputs, as `scope -> token`.

    An exported GITHUB_TOKEN or GH_TOKEN wins outright, otherwise nix.conf
    supplies its `access-tokens`, printed as space-separated `scope=token` pairs.
    Cached because neither source can change within a run.
    """
    if token := os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN"):
        return {GITHUB_HOST: token}

    try:
        tokens = run("nix", "config", "show", "access-tokens", capture=True)
    except CommandError:
        return {}

    return dict(entry.split("=", 1) for entry in tokens.split() if "=" in entry)


def github_token(*scope: str) -> str | None:
    """The token for `github.com/<scope>`, the longest matching prefix winning.

    Nix accepts a scope narrower than a host, so it resolves
    `github.com/owner/repo` ahead of `github.com/owner` ahead of the host-wide
    `github.com`, and this follows suit. An empty scope therefore asks for the
    host-wide token only, the right credential for a caller that reaches
    arbitrary repositories. A token merely lifts the API rate limit from 60 to
    5000 requests per hour, so having none is not an error.
    """
    tokens = access_tokens()
    parts = [GITHUB_HOST, *scope]

    while parts:
        if token := tokens.get("/".join(parts)):
            return token

        parts.pop()

    return None


def is_worktree_of(flake: str) -> bool:
    """Whether the cwd is the working copy of the flake we were resolved from.

    `nix run github:mirkolenz/infra -- update-…` must not rewrite whatever repo
    happens to be the cwd. `flake` is a store snapshot of our own source, so its
    flake.nix matches the one here exactly when this is its working copy — dirty
    included, since `nix run .` snapshots uncommitted edits too.

    Answering this is only sound before we edit anything, which is why `main`
    settles it once at startup: `update deps` rewrites flake.nix, so asking
    again afterwards compares against a snapshot our own bump just made stale.
    """
    target = Path("flake.nix")
    source = Path(flake) / "flake.nix"

    if not target.is_file():
        return False

    return not source.is_file() or source.read_bytes() == target.read_bytes()


def snapshot_worktree() -> str:
    """A commit of the tracked working tree, which `git stash create` makes
    without touching the tree, the index, or the stash list."""
    return run("git", "stash", "create", capture=True).strip() or "HEAD"


def changed_paths(snapshot: str) -> list[str]:
    """The tracked paths under the cwd that differ from `snapshot`."""
    return run_nul("git", "diff", "-z", "--name-only", "--relative", snapshot)


def restore_worktree(snapshot: str, paths: Iterable[str]) -> None:
    """Restore `paths` to `snapshot`, discarding a broken or partial update
    but keeping the edits before it."""
    paths = sorted(set(paths))

    if not paths:
        return

    print(f"Reverting {len(paths)} path(s): {', '.join(paths)}", file=sys.stderr)
    run_logged(["git", "restore", f"--source={snapshot}", "--", *paths])


def commit_dir(path: str, message: str) -> None:
    """Commit anything that changed under a directory, if anything did."""
    status = run("git", "status", "--porcelain", "--", path, capture=True).strip()

    if not status:
        print(f"No {path} changes to commit.", file=sys.stderr)
        return

    run_logged(["git", "add", "--all", "--", path])
    run_logged(["git", "commit", "-m", message, "--", path])


def update_deps(cfg: Config, dry_run: bool) -> None:
    """Update and commit the flake inputs and GitHub Actions through `bumpctl`, then refresh pinned hashes.

    The version tags of the inputs and actions move to their latest major
    releases, honoring `BUMP_MIN_AGE`.
    """
    cfg.require_worktree()

    bump = [*flake_program(cfg, "bumpctl"), "nix", "actions"]
    run_logged([*bump, "--dry-run" if dry_run else "--accept=major"])

    if dry_run:
        return

    if cfg.hash_path:
        # `fix hashes` repairs what nix journaled while building, so a failed build
        # is what gives it anything to do. `.` re-resolves the working tree,
        # `cfg.flake` predates the lockfile rewritten above.
        installable = f".#{cfg.hash_path}"
        hashed = nix_eval_targets(installable)
        # Only this build's mismatches, not stale ones from earlier builds.
        since = str(int(datetime.now(UTC).timestamp()))

        if returncode := build_targets(hashed, check=False):
            snapshot = snapshot_worktree()
            # Non-zero also means "nothing to fix", so the edits decide instead.
            run_logged(
                ["determinate-nixd", "fix", "hashes", "--auto-apply", "--since", since],
                check=False,
            )
            fixed = changed_paths(snapshot)

            if not fixed:
                raise SystemExit(returncode)

            # The fixed sources yield new derivations, so evaluate them again.
            try:
                build_targets(nix_eval_targets(installable))
            except Error:
                restore_worktree(snapshot, fixed)
                raise

    commit_dir("pkgs/", "chore(deps/pkgs): hashing")


def check_build(
    cfg: Config,
    extra_args: Sequence[str],
    path: str | None,
    workers: int,
    max_memory_size: int,
) -> None:
    """Build the CI targets of the current system that no binary cache holds.

    `path` holds the targets per system, like `checks`, so that `cache gc`
    finds what every system pushed under the same path.

    Extra arguments go to nix-fast-build, which builds each target as soon as it
    has evaluated. Its nix-eval-jobs workers are bounded as in `check flake`,
    which evaluates everything else.
    """
    path = path or cfg.build_path

    if not path:
        raise Error("Specify --path or set --build-path.")

    system = run("nix", "config", "show", "system", capture=True).strip()

    run_logged(
        [
            *flake_program(cfg, "nix-fast-build"),
            "--flake",
            f"{cfg.flake}#{path}.{system}",
            "--select",
            BUILD_SELECT,
            "--eval-workers",
            str(workers),
            "--eval-max-memory-size",
            str(max_memory_size),
            "--skip-cached",
            *(["--copy-to", cfg.cache, "--push-build-closure"] if cfg.cache else []),
            *extra_args,
        ]
    )


def hash_part(path: str) -> str:
    """The hash of a store path or its basename, which keys its narinfo."""
    return Path(path).name.split("-", 1)[0]


def build_closure_outputs(drvs: Iterable[str]) -> set[str]:
    """The output paths of `drvs` and of every derivation they depend on.

    Resolved from the store derivations without building or substituting
    anything, which also covers the fixed-output paths that
    `nix derivation show` leaves out.
    """
    requisites = run(
        "nix",
        "path-info",
        "--recursive",
        "--stdin",
        stdin="\n".join(drvs),
        capture=True,
    )
    installables = "\n".join(
        f"{path}^*" for path in requisites.splitlines() if path.endswith(".drv")
    )
    outputs = run_json(
        "nix",
        "path-info",
        "--json",
        "--json-format",
        "2",
        "--option",
        "substitute",
        "false",
        "--stdin",
        stdin=installables,
        capture=True,
    )

    return set(outputs["info"])


def s3_store(url: str) -> S3Store:
    """The bucket of the `s3://` store `url`.

    Reads the `endpoint` and `region` parameters of the store, credentials come
    from the usual AWS environment variables.
    """
    parsed = urllib.parse.urlparse(url)

    if parsed.scheme != "s3":
        raise Error(f"Not an s3:// binary cache: {url}")

    params = dict(urllib.parse.parse_qsl(parsed.query))
    # the defaults of nix, which addresses AWS by region without an endpoint
    region = params.get("region", "us-east-1")
    endpoint = params.get("endpoint", f"https://s3.{region}.amazonaws.com")

    return S3Store(parsed.netloc, endpoint=endpoint, region=region)


def cache_closure(cache: str, paths: Iterable[str]) -> dict[str, Any]:
    """The path infos of `paths` and everything they reference in `cache`, by
    basename, each of them held by `cache`.

    `--refresh` bypasses the local narinfo cache, which may still remember a
    path that the bucket no longer holds.
    """
    infos = run_json(
        "nix",
        "path-info",
        "--refresh",
        "--store",
        cache,
        "--recursive",
        "--json",
        "--json-format",
        "2",
        "--stdin",
        stdin="\n".join(paths),
        capture=True,
    )

    return infos["info"]


def cache_gc(cfg: Config, keep_days: int, dry_run: bool) -> None:
    """Delete what the binary cache holds beyond the closure of the CI targets.

    Keeps the outputs of the current `check build` targets of every system and
    of their build dependencies, which `check build` pushes as well, and the
    paths uploaded within `keep_days`, each with its closure, so that no
    kept path loses a reference. A NAR goes once no kept narinfo points at it
    and it is older than `keep_days`, which spares one whose narinfo is still
    being uploaded.
    """

    if not cfg.cache or not cfg.build_path:
        raise Error("Specify --cache and --build-path.")

    store = s3_store(cfg.cache)
    cutoff = datetime.now(UTC) - timedelta(days=keep_days)
    objects = {
        obj["path"]: obj
        for chunk in obstore.list(store, chunk_size=1000)
        for obj in chunk
    }
    narinfos = {
        key.removesuffix(".narinfo"): obj
        for key, obj in objects.items()
        if key.endswith(".narinfo") and "/" not in key
    }
    drvs = nix_eval_json(f"{cfg.flake}#{cfg.build_path}", "--apply", ROOTS_APPLY)
    roots = {hash_part(path) for path in build_closure_outputs(drvs)}
    recent = {
        digest for digest, obj in narinfos.items() if obj["last_modified"] >= cutoff
    }
    store_dir = nix_eval_json("--expr", "builtins.storeDir")
    # nix finds a path by its hash part, `x` is the name it gives an unknown one
    seeds = [f"{store_dir}/{digest}-x" for digest in narinfos.keys() & (roots | recent)]
    kept = cache_closure(cfg.cache, seeds) if seeds else {}
    live_nars = {info["url"] for info in kept.values()}
    # narinfos first, so that no narinfo outlives its NAR
    stale = [
        *(
            f"{digest}.narinfo"
            for digest in narinfos.keys() - {hash_part(name) for name in kept}
        ),
        *(
            key
            for key, obj in objects.items()
            if key.startswith("nar/")
            and key not in live_nars
            and obj["last_modified"] < cutoff
        ),
    ]
    size = sum(objects[key]["size"] for key in stale)
    print(
        f"Keeping {len(kept)} of {len(narinfos)} paths,"
        f" deleting {len(stale)} objects ({size / 2**30:.2f} GiB).",
        file=sys.stderr,
    )

    if dry_run:
        return

    # bulk deletes in batches of 1000, which S3 allows per request
    try:
        obstore.delete(store, stale)
    except BaseError as error:
        raise Error(str(error)) from error


# A check's outcome and its section of the job summary.
CheckResult = tuple[bool, list[str]]


def fenced(text: str, lang: str = "") -> list[str]:
    """Wrap `text` in a Markdown code block."""
    return [f"```{lang}", text.strip(), "```", ""]


def write_step_summary(lines: Iterable[str]) -> None:
    """Append `lines` to the job summary, if there is one."""
    summary = os.environ.get("GITHUB_STEP_SUMMARY")

    if not summary:
        return

    with Path(summary).open("a") as file:
        file.write("\n".join(lines) + "\n")


def check_fmt() -> CheckResult:
    """Run the formatter, annotating each file it changed."""
    if run_logged(["nix", "fmt", "--", "--ci"], check=False) == 0:
        return True, ["## ✅ Formatting Passed", ""]

    files = run_nul("git", "diff", "-z", "--name-only")

    if not files:
        return False, ["## ❌ Formatting Failed", "", "See the job log.", ""]

    if GITHUB_ACTIONS:
        for file in files:
            print(
                f"::error file={file},title=nix fmt::File is not formatted", flush=True
            )

    diff = run("git", "diff", capture=True).strip()

    return False, [
        f"## ❌ Formatting Failed ({len(files)} files)",
        "",
        *(f"- `{file}`" for file in files),
        "",
        *fenced(diff, "diff"),
    ]


def check_apps(cfg: Config) -> CheckResult:
    """Evaluate the program of every app."""
    try:
        nix_eval_json(f"{cfg.flake}#.apps", "--apply", APPS_APPLY)
    except CommandError as error:
        print(error.stderr, file=sys.stderr)

        return False, ["## ❌ App Evals Failed", "", *fenced(error.stderr)]

    return True, ["## ✅ App Evals Passed", ""]


def colored(text: str, color: int) -> str:
    """Wrap `text` in the ANSI `color` code, unless stderr shows no colors."""
    return f"\033[{color}m{text}\033[0m" if COLOR else text


def eval_jobs(cfg: Config, workers: int, max_memory_size: int) -> CheckResult:
    """Evaluate `EVAL_SELECT` with nix-eval-jobs, reporting each failing attribute.

    A worker is restarted once it exceeds `max_memory_size` MiB, which keeps the
    peak at `workers * max_memory_size` however many configurations the flake has.
    """
    passed: list[str] = []
    failed: dict[str, str] = {}

    with tempfile.TemporaryDirectory() as gc_roots:
        cmd = [
            *flake_program(cfg, "nix-eval-jobs"),
            "--flake",
            cfg.flake,
            "--select",
            EVAL_SELECT,
            "--force-recurse",
            "--workers",
            str(workers),
            "--max-memory-size",
            str(max_memory_size),
            "--gc-roots-dir",
            gc_roots,
        ]
        log_cmd(cmd)

        with subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True) as proc:
            assert proc.stdout is not None

            for line in proc.stdout:
                job = json.loads(line)
                attr = job["attr"]

                error = job.get("error")
                print(
                    colored(f"{'✘' if error else '✔'}  {attr}", 31 if error else 32),
                    file=sys.stderr,
                )

                if error:
                    failed[attr] = error
                    print(error, file=sys.stderr)
                else:
                    passed.append(attr)

    ok = proc.returncode == 0 and not failed
    lines = [
        f"## ✅ Drv Evals Passed ({len(passed)} successful)"
        if ok
        else f"## ❌ Drv Evals Failed ({len(failed)} failed, {len(passed)} successful)",
        "",
    ]

    if proc.returncode:
        lines += [
            f"nix-eval-jobs exited with code {proc.returncode}, see the job log.",
            "",
        ]

    for attr, error in failed.items():
        lines += [f"**`{attr}`**", "", *fenced(error)]

    lines += [
        "<details>",
        f"<summary>Evaluated {len(passed)} derivations</summary>",
        "",
        *(f"- {attr}" for attr in passed),
        "</details>",
        "",
    ]

    return ok, lines


def check_flake(cfg: Config, workers: int, max_memory_size: int) -> None:
    """Check formatting and evaluate what `check build` leaves out.

    Together with `check build` on every system, this covers what
    `nix flake check --no-build --all-systems` evaluates, while the memory of
    evaluation stays bounded. Every step runs, so one failure hides no other.
    """
    cfg.require_worktree()

    results = [
        check_fmt(),
        check_apps(cfg),
        eval_jobs(cfg, workers, max_memory_size),
    ]
    write_step_summary(
        itertools.chain(["# Flake Check", ""], *(lines for _, lines in results))
    )

    if not all(ok for ok, _ in results):
        raise SystemExit(1)


@dataclass(frozen=True, slots=True)
class UpdateScript:
    """A package's resolved `passthru.updateScript` (see update_scripts.nix)."""

    attr_path: str
    name: str
    pname: str
    old_version: str
    homepage: str | None
    position: str | None
    command: list[str]

    @property
    def argv(self) -> list[str]:
        """`env`-prefixed argv exposing the variables updaters expect (nix-update)."""
        return [
            "env",
            f"UPDATE_NIX_NAME={self.name}",
            f"UPDATE_NIX_PNAME={self.pname}",
            f"UPDATE_NIX_OLD_VERSION={self.old_version}",
            f"UPDATE_NIX_ATTR_PATH={self.attr_path}",
            *self.command,
        ]

    @property
    def path(self) -> str | None:
        """Repo-relative source path: the package directory for dir-based
        packages (mirroring `packagesFromDirectoryRecursive`'s package rule),
        else the single file. None when defined outside the working tree."""
        if self.position is None:
            return None

        file = Path(self.position.rsplit(":", 1)[0])
        target = file.parent if file.name == "package.nix" else file
        root = Path.cwd()

        return str(target.relative_to(root)) if target.is_relative_to(root) else None

    @property
    def github_scope(self) -> tuple[str, ...]:
        """The `owner, repo` this package lives at, narrowing its access token.

        `meta.homepage` is where a package records that; anything but a GitHub
        repository yields an empty scope, which falls back to the host-wide
        token."""
        url = urllib.parse.urlparse(self.homepage or "")

        if url.hostname != GITHUB_HOST:
            return ()

        return tuple(url.path.strip("/").split("/")[:2])

    @property
    def wants_github_token(self) -> bool:
        """Whether the script names GITHUB_TOKEN, `--keep GITHUB_TOKEN` included.

        Letting each script declare the need keeps the credential away from the
        updaters that never call the GitHub API, without a flag that nixpkgs
        would not recognize."""
        script = Path(self.command[0])

        return script.is_file() and b"GITHUB_TOKEN" in script.read_bytes()

    def run(self, token: str | None) -> subprocess.CompletedProcess[str]:
        """Run the updateScript, inheriting cwd (repo root) and PATH.

        `token` is the narrowest one covering this package's own repository. It
        reaches a script that asks for it; every other script runs with
        GITHUB_TOKEN unset, so an exported one leaks no further than this."""
        env = dict(os.environ)

        if token is not None and self.wants_github_token:
            env["GITHUB_TOKEN"] = token
        else:
            env.pop("GITHUB_TOKEN", None)

        return subprocess.run(
            self.argv, env=env, capture_output=True, text=True, check=False
        )


def update_scripts_args(
    output: str,
    attr_path: str,
    packages: Iterable[str] | None = None,
) -> list[str]:
    """`nix` args selecting `<output>` from update_scripts.nix for the working tree.

    `packages` narrows the derivations under `attr_path` to those keys before
    anything of them is forced."""
    args = [
        "-f",
        UPDATE_SCRIPTS,
        output,
        "--argstr",
        "root",
        str(Path.cwd()),
        "--argstr",
        "path",
        attr_path,
    ]

    if packages is not None:
        args.extend(["--argstr", "packages", json.dumps(sorted(packages))])

    return args


def discover_update_scripts(
    attr_path: str,
    packages: Iterable[str] | None = None,
) -> dict[str, UpdateScript]:
    """Build and parse the update-scripts manifest for derivations under `attr_path`.

    Building `manifest` realizes every command (carried as Nix string context) so
    the scripts exist before they run; `root` imports the working tree so
    updateScripts edit package files in place.
    """
    out = run(
        "nix",
        "build",
        "--impure",
        *update_scripts_args("manifest", attr_path, packages),
        "--no-link",
        "--print-out-paths",
        capture=True,
    ).strip()

    return {
        key: UpdateScript(**script)
        for key, script in json.loads(Path(out).read_text()).items()
    }


@dataclass(frozen=True, slots=True)
class PackageMeta:
    """A package's version and changelog (see update_scripts.nix)."""

    version: str
    changelog: str | None


def eval_metadata(attr_path: str, packages: Iterable[str]) -> dict[str, PackageMeta]:
    """Current metadata for the updateScript `packages` under `attr_path`.

    Evaluates the `metadata` output, which forces only each version and
    changelog and so realizes nothing (unlike the manifest).
    """
    entries = nix_eval_json(
        "--impure",
        *update_scripts_args("metadata", attr_path, packages),
    )

    return {key: PackageMeta(**meta) for key, meta in entries.items()}


def format_bump(key: str, old_version: str, meta: PackageMeta) -> str:
    """One commit-body line, linked to the changelog where the package has one."""
    bump = f"{key}: {old_version} -> {meta.version}"

    return f"- [{bump}]({meta.changelog})" if meta.changelog else f"- {bump}"


def update_pkgs(cfg: Config, package: str | None, dry_run: bool) -> None:
    """Run each package's `passthru.updateScript` to refresh sources, in parallel, and commit them."""
    cfg.require_worktree()

    if cfg.update_path is None:
        raise Error("update pkgs requires --update-path.")

    print("Discovering updateScripts...", file=sys.stderr)
    scripts = discover_update_scripts(
        cfg.update_path,
        None if package is None else [package],
    )

    if not scripts:
        print("No matching packages with an updateScript.", file=sys.stderr)
        return

    print(
        f"Updating {len(scripts)} package(s): {', '.join(scripts)}",
        file=sys.stderr,
    )

    if dry_run:
        return

    snapshot = snapshot_worktree()
    succeeded: set[str] = set()

    with concurrent.futures.ThreadPoolExecutor(
        max_workers=min(len(scripts), cfg.max_workers)
    ) as pool:
        # Tokens resolve here rather than in `run` so the cached `access-tokens`
        # lookup happens once, on this thread, instead of racing across workers.
        futures = {
            pool.submit(script.run, github_token(*script.github_scope)): key
            for key, script in scripts.items()
        }

        try:
            for future in concurrent.futures.as_completed(futures):
                key = futures[future]
                result = future.result()

                if result.returncode == 0:
                    succeeded.add(key)
                    print(f"{key}: done", file=sys.stderr)
                else:
                    print(f"{key}: FAILED", file=sys.stderr)

                    if result.stderr:
                        print(result.stderr.rstrip(), file=sys.stderr)
        except KeyboardInterrupt:
            # Ctrl+C reaches the whole process group, so running scripts are
            # already dying; cancel the queued ones instead of draining them.
            print("\nInterrupted, stopping...", file=sys.stderr)
            pool.shutdown(cancel_futures=True)
            raise SystemExit(130)

    failures = [key for key in scripts if key not in succeeded]
    restore_worktree(snapshot, (p for key in failures if (p := scripts[key].path)))

    # List every version bump in the commit body (sorted), à la `nix flake update`.
    updated = eval_metadata(cfg.update_path, succeeded) if succeeded else {}
    bumps = [
        format_bump(key, scripts[key].old_version, meta)
        for key, meta in sorted(updated.items())
        if scripts[key].old_version != meta.version
    ]
    message = "chore(deps/pkgs): update"

    if bumps:
        message += "\n\nPackage updates:\n\n" + "\n".join(bumps) + "\n"

    commit_dir("pkgs/", message)

    if failures:
        print(f"Failed: {', '.join(failures)}", file=sys.stderr)


def update_all(cfg: Config, dry_run: bool) -> None:
    """Run `update deps` then `update pkgs` in sequence, committing the updates."""
    update_deps(cfg, dry_run=dry_run)
    update_pkgs(cfg, package=None, dry_run=dry_run)


HELP = "Show this message and exit."

# Keeps the wrapped tool's own --help reachable.
WRAPPER_HELP = "--wrapper-help"


def subcommands(
    parser: argparse.ArgumentParser,
) -> _SubParsersAction[argparse.ArgumentParser]:
    """The commands of `parser`, one of which is required."""
    return parser.add_subparsers(title="commands", metavar="COMMAND", required=True)


def parser() -> argparse.ArgumentParser:
    """The command line, whose global options precede the command."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=HelpFormatter,
        allow_abbrev=False,
        add_help=False,
    )
    parser.add_argument("--help", action="help", help=HELP)
    parser.add_argument("--flake", default=".", help="The flake to act on.")
    parser.add_argument("--impure-attr")
    parser.add_argument("--build-path")
    parser.add_argument("--hash-path")
    parser.add_argument("--update-path")
    parser.add_argument("--cache")
    parser.add_argument(
        "--max-workers", type=int, default=8, help="Update scripts run at once."
    )
    commands = subcommands(parser)

    def command(
        parent: _SubParsersAction[argparse.ArgumentParser],
        func: FunctionType,
        *,
        extra_args: bool = False,
        help_flag: str = "--help",
        parents: Sequence[argparse.ArgumentParser] = (),
    ) -> argparse.ArgumentParser:
        """Add `func` as the command named after its last word, documented by its docstring.

        With `extra_args`, the arguments it does not know go to the tool it wraps.
        """
        subparser = add_command(
            parent,
            func.__name__.rpartition("_")[2],
            func.__doc__,
            parents=parents,
            add_help=False,
        )
        subparser.add_argument(help_flag, action="help", help=HELP)
        subparser.set_defaults(func=func)

        if extra_args:
            subparser.set_defaults(extra_args=[])

        return subparser

    def group(name: str, doc: str) -> _SubParsersAction[argparse.ArgumentParser]:
        """Add the command `name` of subcommands."""
        subparser = add_command(commands, name, doc, add_help=False)
        subparser.add_argument("--help", action="help", help=HELP)

        return subcommands(subparser)

    # nix-eval-jobs bounds, shared by `check build` and `check flake`
    eval_options = argparse.ArgumentParser(add_help=False)
    eval_options.add_argument(
        "--workers", type=int, default=EVAL_WORKERS, help="nix-eval-jobs workers."
    )
    eval_options.add_argument(
        "--max-memory-size",
        type=int,
        default=EVAL_MAX_MEMORY_SIZE,
        help="MiB per worker.",
    )
    dry_run = argparse.ArgumentParser(add_help=False)
    dry_run.add_argument(
        "--dry-run", "-n", action="store_true", help="Show what would change."
    )

    config = command(commands, rebuild, extra_args=True, help_flag=WRAPPER_HELP)
    config.add_argument(
        "--operation",
        "-o",
        "--mode",
        "-m",
        default="switch",
        help="Operation of the configuration tool.",
    )
    config.add_argument("--name", "-n")

    install = group("install", "Install a machine onto its disks.")

    for parent, func in (
        (commands, disko),
        (install, install_disko),
        (install, install_nixos),
    ):
        command(parent, func, extra_args=True, help_flag=WRAPPER_HELP).add_argument(
            "machine"
        )

    password = command(commands, passwd)
    password.add_argument("machine")
    password.add_argument("user")
    password.add_argument(
        "--root", type=Path, default=Path("/"), help="Mount point of the target."
    )

    update = group("update", "Update the flake and its packages.")
    command(update, update_all, parents=[dry_run])
    command(update, update_deps, parents=[dry_run])
    pkgs = command(update, update_pkgs, parents=[dry_run])
    pkgs.add_argument("--package", "-p")

    check = group("check", "Check the flake like CI does.")
    build = command(check, check_build, extra_args=True, parents=[eval_options])
    build.add_argument("--path", "-p")
    command(check, check_flake, parents=[eval_options])

    cache = group("cache", "Maintain the binary cache.")
    gc = command(cache, cache_gc, parents=[dry_run])
    gc.add_argument(
        "--keep-days", type=int, default=30, help="Days to keep any upload."
    )

    return parser


@entrypoint
def main() -> None:
    """Run the command given on the command line."""
    # Kept for every child, nix and the tools running it alike, such as bumpctl or nixos-rebuild.
    config = os.environ.get("NIX_CONFIG")
    os.environ["NIX_CONFIG"] = f"{config}\n{NIX_CONFIG}" if config else NIX_CONFIG
    cli = complete(parser())
    args, extra_args = cli.parse_known_args()

    options = vars(args)
    func: Callable[..., None] = options.pop("func")

    # only commands wrapping a tool declare `extra_args`
    if "extra_args" in options:
        options["extra_args"] = extra_args
    elif extra_args:
        cli.error(f"unrecognized arguments: {shlex.join(extra_args)}")

    config = {
        field.name: options.pop(field.name)
        for field in fields(Config)
        if field.name in options
    }
    cfg = Config(**config, is_worktree=is_worktree_of(config["flake"]))

    func(cfg, **options)


if __name__ == "__main__":
    main()
