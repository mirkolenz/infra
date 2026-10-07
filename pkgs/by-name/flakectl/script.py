import concurrent.futures
import functools
import getpass
import itertools
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import urllib.parse
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Annotated, Any

import httpx2
import obstore
import typer
from obstore.exceptions import BaseError
from obstore.store import S3Store

# Host that `access-tokens` entries are keyed by, and its REST API.
GITHUB_HOST = "github.com"
GITHUB_API = "https://api.github.com"

# Pinned alongside the one in pkgs/by-name/mkGitHubBinary.nix.
GITHUB_API_VERSION = "2026-03-10"

GITHUB_ACTIONS = os.environ.get("GITHUB_ACTIONS") == "true"

# Flags passed to every `nix` invocation.
NIX_FLAGS = ["--extra-experimental-features", "nix-command flakes"]

# Match github inputs pinned to a semver ref (e.g. v1.2.3, release-1.2.3-rc1).
# The store directory and hash of a store path, which logs leave out.
STORE_PATH_PREFIX = re.compile(r"/nix/store/[0-9a-z]{32}-")

GITHUB_SEMVER_REF = re.compile(
    r'url = "github:(?P<owner>[^/"]+)/(?P<repo>[^/"]+)/(?P<ref>[^/"]*\d+\.\d+\.\d+[^/"]*)"'
)


TARGET_APPLY = "builtins.mapAttrs (_: drv: drv.drvPath)"

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

# `check-build`: the targets of one system's `checks` that CI builds.
BUILD_SELECT = f"""
let
  isHydraTarget = {IS_HYDRA_TARGET};
  filterAttrs = {FILTER_ATTRS};
in
filterAttrs isHydraTarget
"""

# `check-flake`: every derivation `nix flake check` evaluates that `check-build`
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

# `gc-cache`: the store derivations of the targets that `check-build` builds
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

# nix-eval-jobs bounds shared by `check-flake` and `check-build`. A worker past
# its share is restarted, so peak memory stays at `workers * max_memory_size` MiB.
# One worker of 6 GiB fits any host as well as the largest single configuration
# (about 4.7 GB).
EvalWorkers = Annotated[int, typer.Option("--workers")]
EvalMaxMemorySize = Annotated[
    int, typer.Option("--max-memory-size", help="MiB per worker.")
]
EVAL_WORKERS = 1
EVAL_MAX_MEMORY_SIZE = 6144


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
    flake: str
    update_scripts_nix: str | None
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
            typer.echo("Not this flake's working copy; run from a checkout.", err=True)
            raise typer.Exit(1)


def subprocess_capture(
    cmd: list[str], stdin: str | None = None, env: Mapping[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    """Run `cmd` with its output captured as text, leaving failure to the caller."""
    return subprocess.run(
        cmd, input=stdin, env=env, capture_output=True, text=True, check=False
    )


def subprocess_stdout(cmd: list[str], stdin: str | None = None) -> str:
    """Capture `cmd`'s stdout; on failure echo its stderr and exit with its status."""
    result = subprocess_capture(cmd, stdin)

    if result.returncode:
        typer.echo(result.stderr.rstrip(), err=True)
        raise typer.Exit(result.returncode)

    return result.stdout.strip()


def log_cmd(cmd: list[str]) -> None:
    """Echo `cmd` to stderr in short.

    Leading NIX_FLAGS are elided, `nix run <flake>#<package> --` shows as the
    package alone, and store paths as their names.
    """
    head, *tail = cmd

    if tail[: len(NIX_FLAGS)] == NIX_FLAGS:
        tail = tail[len(NIX_FLAGS) :]

    if head == "nix" and tail[:1] == ["run"] and tail[2:3] == ["--"]:
        head, tail = tail[1].rpartition("#")[2], tail[3:]

    typer.echo(
        shlex.join(STORE_PATH_PREFIX.sub("", arg) for arg in [head, *tail]), err=True
    )


def run_logged(cmd: list[str], *, check: bool = True) -> int:
    """Log `cmd` then run it.

    Failure exits with `cmd`'s own status rather than raising: `cmd` reported it
    on our stderr already, and a traceback would only displace that. Pass
    `check=False` for a command whose failure is not fatal.
    """
    log_cmd(cmd)
    returncode = subprocess.run(cmd, check=False).returncode

    if returncode and check:
        raise typer.Exit(returncode)

    return returncode


def nix_argv(*args: str) -> list[str]:
    """Build a `nix` argv with the standard flags prepended."""
    return ["nix", *NIX_FLAGS, *args]


def flake_program(cfg: Config, package: str) -> list[str]:
    """Run the main program of the flake's `package`.

    Only nix and git are bundled, every other tool is pinned by the flake just
    like the configurations it acts on, and only fetched by the commands using
    it. This also works on a fresh machine that has nothing but Nix.
    """
    return nix_argv("run", f"{cfg.flake}#{package}", "--")


def flake_ref(flake: str, attr_path: str, name: str) -> str:
    """Installable for `name` within `attr_path`.

    The name is quoted so a dot in it stays one attribute, and the leading dot
    makes `attr_path` absolute, so nix neither looks it up in `packages.<system>`
    first nor builds a same-named package instead."""
    return f'{flake}#.{attr_path}."{name}"'


def nix_eval_json(*args: str) -> Any:
    """Evaluate a nix expression to JSON and parse it."""
    return json.loads(subprocess_stdout(nix_argv("eval", "--json", *args)))


def nix_eval_targets(installable: str) -> dict[str, BuildTarget]:
    """Evaluate `installable` and assert it returns `{name: derivation}`."""
    entries = nix_eval_json(installable, "--apply", TARGET_APPLY)

    if not isinstance(entries, dict) or not all(
        isinstance(drv, str) and drv.endswith(".drv") for drv in entries.values()
    ):
        typer.echo(
            f"nix eval {installable} did not return an attrset of derivations",
            err=True,
        )
        raise typer.Exit(1)

    return {name: BuildTarget(drv_path=drv) for name, drv in entries.items()}


def build_targets(targets: Mapping[str, BuildTarget], *, check: bool = True) -> int:
    """Build the store derivations of `targets` without evaluating again."""
    if not targets:
        return 0

    refs = [target.installable for target in targets.values()]

    return run_logged(nix_argv("build", "--no-link", *refs), check=check)


# Hand unknown options on to the wrapped tool.
EXTRA_ARGS = {"allow_extra_args": True, "ignore_unknown_options": True}

# Additionally keep the wrapped tool's own --help reachable.
PASSTHROUGH = {**EXTRA_ARGS, "help_option_names": ["--wrapper-help"]}


app = typer.Typer(
    add_completion=False,
    pretty_exceptions_enable=False,
    help="Unified toolkit for managing a NixOS flake.",
)


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    update_scripts_nix: Annotated[str | None, typer.Option()] = None,
    flake: Annotated[str, typer.Option()] = ".",
    impure_attr: Annotated[str | None, typer.Option()] = None,
    build_path: Annotated[str | None, typer.Option()] = None,
    hash_path: Annotated[str | None, typer.Option()] = None,
    update_path: Annotated[str | None, typer.Option()] = None,
    cache: Annotated[str | None, typer.Option()] = None,
    max_workers: Annotated[int, typer.Option()] = 8,
):
    ctx.obj = Config(**ctx.params, is_worktree=is_worktree_of(flake))

    # the Actions log renders colors although stderr is a pipe there
    if GITHUB_ACTIONS:
        ctx.color = True

    if ctx.invoked_subcommand is None:
        build_config(ctx)


@app.command("build-config", context_settings=PASSTHROUGH)
def build_config(
    ctx: typer.Context,
    operation: Annotated[
        str, typer.Option("--operation", "-o", "--mode", "-m")
    ] = "switch",
    name: Annotated[str | None, typer.Option("--name", "-n")] = None,
):
    """Build and apply a darwin / nixos / home-manager configuration."""
    cfg: Config = ctx.obj
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
    run_flake_tool(ctx, builder, name, operation, *impure)


def run_flake_tool(ctx: typer.Context, package: str, name: str, *args: str) -> None:
    """Run the flake's `package` on its configuration `name`, extra args last."""
    cfg: Config = ctx.obj
    run_logged(
        [
            *flake_program(cfg, package),
            *args,
            "--flake",
            f"{cfg.flake}#{name}",
            *ctx.args,
        ]
    )


@app.command("disko", context_settings=PASSTHROUGH)
def disko(ctx: typer.Context, machine: Annotated[str, typer.Argument()]):
    """Partition, format, and mount the disks of `machine`."""
    run_flake_tool(ctx, "disko", machine)


@app.command("disko-install", context_settings=PASSTHROUGH)
def disko_install(ctx: typer.Context, machine: Annotated[str, typer.Argument()]):
    """Partition the disks of `machine` and install it in one go."""
    run_flake_tool(ctx, "disko-install", machine)


@app.command("nixos-install", context_settings=PASSTHROUGH)
def nixos_install(ctx: typer.Context, machine: Annotated[str, typer.Argument()]):
    """Install `machine` onto the disks that `disko` mounted."""
    run_flake_tool(
        ctx, "nixos-install", machine, "--no-channel-copy", "--no-root-password"
    )


def set_root_owned(path: Path, mode: int) -> None:
    """Hand `path` to root with `mode`, out of reach of every other user."""
    path.chmod(mode)
    shutil.chown(path, 0, 0)


@app.command("passwd")
def passwd(
    ctx: typer.Context,
    machine: Annotated[str, typer.Argument()],
    user: Annotated[str, typer.Argument()],
    root: Annotated[Path, typer.Option(help="Mount point of the target.")] = Path("/"),
):
    """Hash a prompted password into the `hashedPasswordFile` of `user` on `machine`.

    The path comes from the NixOS configuration, so it cannot drift from the one
    the system reads. Pass `--root /mnt` for an installer target.
    """
    cfg: Config = ctx.obj

    # Checked up front rather than left to the chown: nobody should type a
    # password only to be told afterwards that it could not be stored.
    if os.geteuid() != 0:
        typer.echo("passwd must run as root.", err=True)
        raise typer.Exit(1)

    if not root.is_dir():
        typer.echo(f"Root {root} is no directory.", err=True)
        raise typer.Exit(1)

    # Nix itself reports a missing machine or user, suggesting similar names.
    target: str | None = nix_eval_json(
        f"{flake_ref(cfg.flake, 'nixosConfigurations', machine)}"
        f'.config.users.users."{user}".hashedPasswordFile',
    )

    if target is None:
        typer.echo(f"{machine} sets no hashedPasswordFile for {user}.", err=True)
        raise typer.Exit(1)

    path = Path(target)

    if not path.is_absolute() or path.is_relative_to("/nix/store"):
        typer.echo(f"Refusing to write {path}, not a mutable path.", err=True)
        raise typer.Exit(1)

    file = root / path.relative_to("/")
    # Fetched up front, so that hashing takes no wait once the password is typed,
    # and the later `nix run` resolves it from the evaluation cache.
    subprocess_stdout(nix_argv("build", "--no-link", f"{cfg.flake}#mkpasswd"))
    typer.echo(f"Setting the password of {user}@{machine} in {file}", err=True)
    password = typer.prompt("New password", hide_input=True, confirmation_prompt=True)

    if not password:
        typer.echo("No password supplied.", err=True)
        raise typer.Exit(1)

    # Hand the password over on stdin; argv is world-readable via /proc.
    hashed = subprocess_stdout(
        [*flake_program(cfg, "mkpasswd"), "--method=yescrypt", "--stdin"],
        password,
    )
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
    typer.echo(f"Wrote {file}, rebuild the configuration to apply.", err=True)


@functools.cache
def access_tokens() -> Mapping[str, str]:
    """The credentials nix itself uses to fetch inputs, as `scope -> token`.

    An exported GITHUB_TOKEN wins outright, otherwise nix.conf supplies its
    `access-tokens`, printed as space-separated `scope=token` pairs. Cached
    because neither source can change within a run.
    """
    if token := os.environ.get("GITHUB_TOKEN"):
        return {GITHUB_HOST: token}

    result = subprocess_capture(nix_argv("config", "show", "access-tokens"))

    if result.returncode != 0:
        return {}

    return dict(entry.split("=", 1) for entry in result.stdout.split() if "=" in entry)


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


def github_client() -> httpx2.Client:
    """A pooled client for the GitHub REST API, credentials left to each request."""
    return httpx2.Client(
        base_url=GITHUB_API,
        timeout=30,
        follow_redirects=True,
        headers={
            "accept": "application/vnd.github+json",
            "x-github-api-version": GITHUB_API_VERSION,
        },
    )


def get_latest_release(client: httpx2.Client, owner: str, repo: str) -> str | None:
    """The latest release tag from the GitHub API, or None if there is none.

    Any failure answers None rather than raising: unauthenticated runs hit the
    rate limit and archived repos have no release, neither of which should stop
    the remaining inputs from being updated."""
    token = github_token(owner, repo)

    try:
        response = client.get(
            f"/repos/{owner}/{repo}/releases/latest",
            headers={"authorization": f"Bearer {token}"} if token else None,
        )
        response.raise_for_status()
        release: Any = response.json()
    except (httpx2.HTTPError, ValueError):
        return None

    tag = release.get("tag_name") if isinstance(release, dict) else None

    return tag if isinstance(tag, str) and tag else None


def latest_releases(cfg: Config, content: str) -> Mapping[tuple[str, str], str | None]:
    """The latest tag of every repo `content` pins, fetched concurrently.

    Resolving up front keeps the substitution itself a pure lookup, so the
    requests overlap while the log still reports them in flake.nix order, and a
    repo pinned by several inputs costs a single request."""
    repos = sorted(
        {(m["owner"], m["repo"]) for m in GITHUB_SEMVER_REF.finditer(content)}
    )

    if not repos:
        return {}

    with (
        github_client() as client,
        concurrent.futures.ThreadPoolExecutor(
            max_workers=min(len(repos), cfg.max_workers)
        ) as pool,
    ):
        tags = pool.map(lambda repo: get_latest_release(client, *repo), repos)

        return dict(zip(repos, tags, strict=True))


def replace_github_ref(
    latest: Mapping[tuple[str, str], str | None], match: re.Match[str]
) -> str:
    owner, repo, current = match.group("owner", "repo", "ref")
    tag = latest[owner, repo]

    if tag is None:
        typer.echo(f"{owner}/{repo}: no release found", err=True)
        return match[0]
    if tag == current:
        typer.echo(f"{owner}/{repo}: up to date ({current})", err=True)
        return match[0]

    typer.echo(f"{owner}/{repo}: {current} -> {tag}", err=True)
    return f'url = "github:{owner}/{repo}/{tag}"'


def is_worktree_of(flake: str) -> bool:
    """Whether the cwd is the working copy of the flake we were resolved from.

    `nix run github:mirkolenz/infra -- update-…` must not rewrite whatever repo
    happens to be the cwd. `flake` is a store snapshot of our own source, so its
    flake.nix matches the one here exactly when this is its working copy — dirty
    included, since `nix run .` snapshots uncommitted edits too.

    Answering this is only sound before we edit anything, which is why `main`
    settles it once at startup: `update-flake` rewrites flake.nix, so asking
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
    return subprocess_stdout(["git", "stash", "create"]) or "HEAD"


def changed_paths(snapshot: str) -> list[str]:
    """The tracked paths under the cwd that differ from `snapshot`."""
    return subprocess_stdout(
        ["git", "diff", "--name-only", "--relative", snapshot]
    ).splitlines()


def restore_worktree(snapshot: str, paths: Iterable[str]) -> None:
    """Restore `paths` to `snapshot`, discarding a broken or partial update
    but keeping the edits before it."""
    paths = sorted(set(paths))

    if not paths:
        return

    typer.echo(f"Reverting {len(paths)} path(s): {', '.join(paths)}", err=True)
    run_logged(["git", "restore", f"--source={snapshot}", "--", *paths])


def commit_pkgs(message: str) -> None:
    """Commit anything that changed under pkgs/, if anything did."""
    status = subprocess_stdout(["git", "status", "--porcelain", "--", "pkgs/"])

    if not status:
        typer.echo("No pkgs/ changes to commit.", err=True)
        return

    run_logged(["git", "add", "--all", "--", "pkgs/"])
    run_logged(["git", "commit", "-m", message, "--", "pkgs/"])


@app.command("update-flake")
def update_flake(
    ctx: typer.Context,
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
    commit: Annotated[bool, typer.Option("--commit", "-c")] = False,
    update: Annotated[bool, typer.Option("--update", "-u")] = True,
):
    """Update flake.nix github inputs and lockfile; refresh pinned hashes."""
    cfg: Config = ctx.obj
    cfg.require_worktree()
    flake_file = Path("flake.nix")
    content = flake_file.read_text()
    latest = latest_releases(cfg, content)
    new_content = GITHUB_SEMVER_REF.sub(
        lambda m: replace_github_ref(latest, m), content
    )

    if dry_run:
        typer.echo("Dry run, no changes written", err=True)
        raise typer.Exit(0)

    flake_changed = new_content != content

    if flake_changed:
        flake_file.write_text(new_content)
    else:
        typer.echo("No changes needed", err=True)

    nix_cmd = nix_argv("flake", "update" if update else "lock")
    if commit:
        nix_cmd.append("--commit-lock-file")
    run_logged(nix_cmd)

    # Amend into nix's lockfile commit to preserve its auto-generated message.
    if commit and flake_changed:
        run_logged(["git", "commit", "--amend", "--no-edit", str(flake_file)])

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
                raise typer.Exit(returncode)

            # The fixed sources yield new derivations, so evaluate them again.
            try:
                build_targets(nix_eval_targets(installable))
            except typer.Exit:
                restore_worktree(snapshot, fixed)
                raise

    if commit:
        commit_pkgs("chore(deps/pkgs): hashing")


@app.command("check-build", context_settings=EXTRA_ARGS)
def check_build(
    ctx: typer.Context,
    path: Annotated[str | None, typer.Option("--path", "-p")] = None,
    workers: EvalWorkers = EVAL_WORKERS,
    max_memory_size: EvalMaxMemorySize = EVAL_MAX_MEMORY_SIZE,
):
    """Build the CI targets of the current system that no binary cache holds.

    `path` holds the targets per system, like `checks`, so that `gc-cache`
    finds what every system pushed under the same path.

    Extra arguments go to nix-fast-build, which builds each target as soon as it
    has evaluated. Its nix-eval-jobs workers are bounded as in `check-flake`,
    which evaluates everything else.
    """
    cfg: Config = ctx.obj
    path = path or cfg.build_path

    if not path:
        typer.echo("Specify --path or set --build-path.", err=True)
        raise typer.Exit(1)

    system = subprocess_stdout(nix_argv("config", "show", "system"))

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
            *ctx.args,
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
    requisites = subprocess_stdout(
        nix_argv("path-info", "--recursive", "--stdin"), "\n".join(drvs)
    )
    installables = "\n".join(
        f"{path}^*" for path in requisites.splitlines() if path.endswith(".drv")
    )
    outputs = subprocess_stdout(
        nix_argv(
            "path-info",
            "--json",
            "--json-format",
            "2",
            "--option",
            "substitute",
            "false",
            "--stdin",
        ),
        installables,
    )

    return set(json.loads(outputs)["info"])


def s3_store(url: str) -> S3Store:
    """The bucket of the `s3://` store `url`.

    Reads the `endpoint` and `region` parameters of the store, credentials come
    from the usual AWS environment variables.
    """
    parsed = urllib.parse.urlparse(url)

    if parsed.scheme != "s3":
        typer.echo(f"Not an s3:// binary cache: {url}", err=True)
        raise typer.Exit(1)

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
    stdout = subprocess_stdout(
        nix_argv(
            "path-info",
            "--refresh",
            "--store",
            cache,
            "--recursive",
            "--json",
            "--json-format",
            "2",
            "--stdin",
        ),
        "\n".join(paths),
    )

    return json.loads(stdout)["info"]


@app.command("gc-cache")
def gc_cache(
    ctx: typer.Context,
    keep_days: Annotated[int, typer.Option()] = 30,
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
):
    """Delete what the binary cache holds beyond the closure of the CI targets.

    Keeps the outputs of the current `check-build` targets of every system and
    of their build dependencies, which `check-build` pushes as well, and the
    paths uploaded within `keep_days`, each with its closure, so that no
    kept path loses a reference. A NAR goes once no kept narinfo points at it
    and it is older than `keep_days`, which spares one whose narinfo is still
    being uploaded.
    """
    cfg: Config = ctx.obj

    if not cfg.cache or not cfg.build_path:
        typer.echo("Specify --cache and --build-path.", err=True)
        raise typer.Exit(1)

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
    typer.echo(
        f"Keeping {len(kept)} of {len(narinfos)} paths,"
        f" deleting {len(stale)} objects ({size / 2**30:.2f} GiB).",
        err=True,
    )

    if dry_run:
        return

    # bulk deletes in batches of 1000, which S3 allows per request
    try:
        obstore.delete(store, stale)
    except BaseError as error:
        typer.echo(str(error), err=True)
        raise typer.Exit(1) from error


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


def check_fmt(cfg: Config) -> CheckResult:
    """Run the formatter, annotating each file it changed."""
    if run_logged(nix_argv("fmt", "--", "--ci"), check=False) == 0:
        return True, ["## ✅ Formatting Passed", ""]

    files = subprocess_stdout(["git", "diff", "--name-only"]).splitlines()

    if not files:
        return False, ["## ❌ Formatting Failed", "", "See the job log.", ""]

    if GITHUB_ACTIONS:
        for file in files:
            typer.echo(f"::error file={file},title=nix fmt::File is not formatted")

    diff = subprocess_stdout(["git", "diff"])

    return False, [
        f"## ❌ Formatting Failed ({len(files)} files)",
        "",
        *(f"- `{file}`" for file in files),
        "",
        *fenced(diff, "diff"),
    ]


def check_apps(cfg: Config) -> CheckResult:
    """Evaluate the program of every app."""
    apps = subprocess_capture(
        nix_argv("eval", "--json", f"{cfg.flake}#.apps", "--apply", APPS_APPLY)
    )

    if apps.returncode:
        typer.echo(apps.stderr.rstrip(), err=True)

        return False, ["## ❌ App Evals Failed", "", *fenced(apps.stderr)]

    return True, ["## ✅ App Evals Passed", ""]


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
                typer.secho(
                    f"{'✘' if error else '✔'}  {attr}",
                    fg="red" if error else "green",
                    err=True,
                )

                if error:
                    failed[attr] = error
                    typer.echo(error, err=True)
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


@app.command("check-flake")
def check_flake(
    ctx: typer.Context,
    workers: EvalWorkers = EVAL_WORKERS,
    max_memory_size: EvalMaxMemorySize = EVAL_MAX_MEMORY_SIZE,
):
    """Check formatting and evaluate what `check-build` leaves out.

    Together with `check-build` on every system, this covers what
    `nix flake check --no-build --all-systems` evaluates, while the memory of
    evaluation stays bounded. Every step runs, so one failure hides no other.
    """
    cfg: Config = ctx.obj
    cfg.require_worktree()

    results = [
        check_fmt(cfg),
        check_apps(cfg),
        eval_jobs(cfg, workers, max_memory_size),
    ]
    write_step_summary(
        itertools.chain(["# Flake Check", ""], *(lines for _, lines in results))
    )

    if not all(ok for ok, _ in results):
        raise typer.Exit(1)


@dataclass(frozen=True, slots=True)
class UpdateScript:
    """A package's resolved `passthru.updateScript` (see update-scripts.nix)."""

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

        return subprocess_capture(self.argv, env=env)


def update_scripts_args(
    update_scripts_nix: str,
    output: str,
    attr_path: str,
    packages: Iterable[str] | None = None,
) -> list[str]:
    """`nix` args selecting `<output>` from update-scripts.nix for the working tree.

    `packages` narrows the derivations under `attr_path` to those keys before
    anything of them is forced."""
    args = [
        "-f",
        update_scripts_nix,
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
    update_scripts_nix: str,
    attr_path: str,
    packages: Iterable[str] | None = None,
) -> dict[str, UpdateScript]:
    """Build and parse the update-scripts manifest for derivations under `attr_path`.

    Building `manifest` realizes every command (carried as Nix string context) so
    the scripts exist before they run; `root` imports the working tree so
    updateScripts edit package files in place.
    """
    out = subprocess_stdout(
        nix_argv(
            "build",
            "--impure",
            *update_scripts_args(update_scripts_nix, "manifest", attr_path, packages),
            "--no-link",
            "--print-out-paths",
        )
    )

    return {
        key: UpdateScript(**fields)
        for key, fields in json.loads(Path(out).read_text()).items()
    }


@dataclass(frozen=True, slots=True)
class PackageMeta:
    """A package's version and changelog (see update-scripts.nix)."""

    version: str
    changelog: str | None


def eval_metadata(
    update_scripts_nix: str, attr_path: str, packages: Iterable[str]
) -> dict[str, PackageMeta]:
    """Current metadata for the updateScript `packages` under `attr_path`.

    Evaluates the `metadata` output, which forces only each version and
    changelog and so realizes nothing (unlike the manifest).
    """
    entries = nix_eval_json(
        "--impure",
        *update_scripts_args(update_scripts_nix, "metadata", attr_path, packages),
    )

    return {key: PackageMeta(**fields) for key, fields in entries.items()}


def format_bump(key: str, old_version: str, meta: PackageMeta) -> str:
    """One commit-body line, linked to the changelog where the package has one."""
    bump = f"{key}: {old_version} -> {meta.version}"

    return f"- [{bump}]({meta.changelog})" if meta.changelog else f"- {bump}"


@app.command("update-pkgs")
def update_pkgs(
    ctx: typer.Context,
    package: Annotated[str | None, typer.Option("--package", "-p")] = None,
    commit: Annotated[bool, typer.Option("--commit", "-c")] = False,
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
):
    """Run each package's `passthru.updateScript` to refresh sources, in parallel."""
    cfg: Config = ctx.obj
    cfg.require_worktree()

    if cfg.update_path is None or cfg.update_scripts_nix is None:
        typer.echo(
            "update-pkgs requires --update-path and --update-scripts-nix.", err=True
        )
        raise typer.Exit(1)

    typer.echo("Discovering updateScripts...", err=True)
    scripts = discover_update_scripts(
        cfg.update_scripts_nix,
        cfg.update_path,
        None if package is None else [package],
    )

    if not scripts:
        typer.echo("No matching packages with an updateScript.", err=True)
        raise typer.Exit(0)

    typer.echo(
        f"Updating {len(scripts)} package(s): {', '.join(scripts)}",
        err=True,
    )

    if dry_run:
        raise typer.Exit(0)

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
                    typer.echo(f"{key}: done", err=True)
                else:
                    typer.echo(f"{key}: FAILED", err=True)

                    if result.stderr:
                        typer.echo(result.stderr.rstrip(), err=True)
        except KeyboardInterrupt:
            # Ctrl+C reaches the whole process group, so running scripts are
            # already dying; cancel the queued ones instead of draining them.
            typer.echo("\nInterrupted, stopping...", err=True)
            pool.shutdown(cancel_futures=True)
            raise typer.Exit(130)

    failures = [key for key in scripts if key not in succeeded]
    restore_worktree(snapshot, (p for key in failures if (p := scripts[key].path)))

    if commit:
        # List every version bump in the commit body (sorted), à la `nix flake update`.
        updated = (
            eval_metadata(cfg.update_scripts_nix, cfg.update_path, succeeded)
            if succeeded
            else {}
        )
        bumps = [
            format_bump(key, scripts[key].old_version, meta)
            for key, meta in sorted(updated.items())
            if scripts[key].old_version != meta.version
        ]
        message = "chore(deps/pkgs): update"

        if bumps:
            message += "\n\nPackage updates:\n\n" + "\n".join(bumps) + "\n"

        commit_pkgs(message)

    if failures:
        typer.echo(f"Failed: {', '.join(failures)}", err=True)


@app.command("update-all")
def update_all(
    ctx: typer.Context,
    commit: Annotated[bool, typer.Option("--commit", "-c")] = True,
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
):
    """Run update-flake then update-pkgs in sequence."""
    update_flake(ctx, commit=commit, dry_run=dry_run)
    update_pkgs(ctx, commit=commit, dry_run=dry_run)


if __name__ == "__main__":
    app()
