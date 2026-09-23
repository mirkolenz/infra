import concurrent.futures
import functools
import getpass
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import urllib.parse
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated, Any

import httpx2
import typer

# Host that `access-tokens` entries are keyed by, and its REST API.
GITHUB_HOST = "github.com"
GITHUB_API = "https://api.github.com"

# Pinned alongside the one in pkgs/by-name/mkGitHubBinary.nix.
GITHUB_API_VERSION = "2026-03-10"

# Flags passed to every `nix` invocation.
NIX_FLAGS = ["--extra-experimental-features", "nix-command flakes"]

# Match github inputs pinned to a semver ref (e.g. v1.2.3, release-1.2.3-rc1).
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
    nix_exe: str
    nix_eval_jobs_exe: str
    nix_fast_build_exe: str
    git_exe: str
    update_scripts_nix: str | None
    nixd_exe: str
    mkpasswd_exe: str
    darwin_builder: str
    linux_builder: str
    home_builder: str
    impure_attr: str | None
    build_path: str | None
    hash_path: str | None
    update_path: str | None
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


def run_logged(cmd: list[str], *, check: bool = True) -> int:
    """Log `cmd` (basename argv0, leading NIX_FLAGS elided) then run it.

    Failure exits with `cmd`'s own status rather than raising: `cmd` reported it
    on our stderr already, and a traceback would only displace that. Pass
    `check=False` for a command whose failure is not fatal.
    """
    head, *tail = cmd

    if tail[: len(NIX_FLAGS)] == NIX_FLAGS:
        tail = tail[len(NIX_FLAGS) :]

    typer.echo(shlex.join([Path(head).name, *tail]), err=True)

    returncode = subprocess.run(cmd, check=False).returncode

    if returncode and check:
        raise typer.Exit(returncode)

    return returncode


def nix_argv(nix_exe: str, *args: str) -> list[str]:
    """Build a `nix` argv with the standard flags prepended."""
    return [nix_exe, *NIX_FLAGS, *args]


def flake_ref(flake: str, attr_path: str, name: str) -> str:
    """Installable for `name` within `attr_path`.

    The name is quoted so a dot in it stays one attribute, and the leading dot
    makes `attr_path` absolute, so nix neither looks it up in `packages.<system>`
    first nor builds a same-named package instead."""
    return f'{flake}#.{attr_path}."{name}"'


def nix_eval_json(nix_exe: str, *args: str) -> Any:
    """Evaluate a nix expression to JSON and parse it."""
    return json.loads(subprocess_stdout(nix_argv(nix_exe, "eval", "--json", *args)))


def nix_eval_targets(nix_exe: str, installable: str) -> dict[str, BuildTarget]:
    """Evaluate `installable` and assert it returns `{name: derivation}`."""
    entries = nix_eval_json(nix_exe, installable, "--apply", TARGET_APPLY)

    if not isinstance(entries, dict) or not all(
        isinstance(drv, str) and drv.endswith(".drv") for drv in entries.values()
    ):
        typer.echo(
            f"nix eval {installable} did not return an attrset of derivations",
            err=True,
        )
        raise typer.Exit(1)

    return {name: BuildTarget(drv_path=drv) for name, drv in entries.items()}


def build_targets(
    nix_exe: str, targets: Mapping[str, BuildTarget], *, check: bool = True
) -> None:
    """Build the store derivations of `targets` without evaluating again."""
    if not targets:
        return

    refs = [target.installable for target in targets.values()]
    run_logged(nix_argv(nix_exe, "build", "--no-link", *refs), check=check)


app = typer.Typer(
    add_completion=False,
    pretty_exceptions_enable=False,
    help="Unified toolkit for managing a NixOS flake.",
)


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    nix_exe: Annotated[str, typer.Option()] = "nix",
    nix_eval_jobs_exe: Annotated[str, typer.Option()] = "nix-eval-jobs",
    nix_fast_build_exe: Annotated[str, typer.Option()] = "nix-fast-build",
    git_exe: Annotated[str, typer.Option()] = "git",
    update_scripts_nix: Annotated[str | None, typer.Option()] = None,
    nixd_exe: Annotated[str, typer.Option()] = "determinate-nixd",
    mkpasswd_exe: Annotated[str, typer.Option()] = "mkpasswd",
    darwin_builder: Annotated[str, typer.Option()] = "darwin-rebuild",
    linux_builder: Annotated[str, typer.Option()] = "nixos-rebuild",
    home_builder: Annotated[str, typer.Option()] = "home-manager",
    flake: Annotated[str, typer.Option()] = ".",
    impure_attr: Annotated[str | None, typer.Option()] = None,
    build_path: Annotated[str | None, typer.Option()] = None,
    hash_path: Annotated[str | None, typer.Option()] = None,
    update_path: Annotated[str | None, typer.Option()] = None,
    max_workers: Annotated[int, typer.Option()] = 8,
):
    ctx.obj = Config(**ctx.params, is_worktree=is_worktree_of(flake))

    # the Actions log renders colors although stderr is a pipe there
    if os.environ.get("GITHUB_ACTIONS") == "true":
        ctx.color = True

    if ctx.invoked_subcommand is None:
        build_config(ctx)


@app.command(
    "build-config",
    context_settings={
        "allow_extra_args": True,
        "ignore_unknown_options": True,
        # Avoid colliding with the underlying builder's --help.
        "help_option_names": ["--wrapper-help"],
    },
)
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
        builder, attr = cfg.home_builder, "homeConfigurations"
    elif kernel == "darwin":
        builder, attr = cfg.darwin_builder, "darwinConfigurations"
    else:
        builder, attr = cfg.linux_builder, "nixosConfigurations"

    is_impure = False

    if cfg.impure_attr:
        is_impure = nix_eval_json(
            cfg.nix_exe, f"{flake_ref(cfg.flake, attr, name)}.{cfg.impure_attr}"
        )

    cmd: list[str] = [builder, operation, "--flake", f"{cfg.flake}#{name}"]

    if is_impure:
        cmd.append("--impure")

    cmd.extend(ctx.args)

    run_logged(cmd)


def set_root_owned(path: Path, mode: int) -> None:
    """Hand `path` to root with `mode`, out of reach of every other user."""
    path.chmod(mode)
    shutil.chown(path, 0, 0)


@app.command("passwd")
def passwd(ctx: typer.Context, file: Annotated[Path, typer.Argument()]):
    """Hash a prompted password into `file`, for `users.users.*.hashedPasswordFile`.

    Takes the path verbatim, so the same command serves a running system and an
    installer target under /mnt.
    """
    cfg: Config = ctx.obj

    # Checked up front rather than left to the chown: nobody should type a
    # password only to be told afterwards that it could not be stored.
    if os.geteuid() != 0:
        typer.echo("passwd must run as root.", err=True)
        raise typer.Exit(1)

    password = typer.prompt("New password", hide_input=True, confirmation_prompt=True)

    if not password:
        typer.echo("No password supplied.", err=True)
        raise typer.Exit(1)

    # Hand the password over on stdin; argv is world-readable via /proc.
    hashed = subprocess_stdout(
        [cfg.mkpasswd_exe, "--method=yescrypt", "--stdin"], password
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
def access_tokens(nix_exe: str) -> Mapping[str, str]:
    """The credentials nix itself uses to fetch inputs, as `scope -> token`.

    An exported GITHUB_TOKEN wins outright, otherwise nix.conf supplies its
    `access-tokens`, printed as space-separated `scope=token` pairs. Cached
    because neither source can change within a run.
    """
    if token := os.environ.get("GITHUB_TOKEN"):
        return {GITHUB_HOST: token}

    result = subprocess_capture(nix_argv(nix_exe, "config", "show", "access-tokens"))

    if result.returncode != 0:
        return {}

    return dict(entry.split("=", 1) for entry in result.stdout.split() if "=" in entry)


def github_token(nix_exe: str, *scope: str) -> str | None:
    """The token for `github.com/<scope>`, the longest matching prefix winning.

    Nix accepts a scope narrower than a host, so it resolves
    `github.com/owner/repo` ahead of `github.com/owner` ahead of the host-wide
    `github.com`, and this follows suit. An empty scope therefore asks for the
    host-wide token only, the right credential for a caller that reaches
    arbitrary repositories. A token merely lifts the API rate limit from 60 to
    5000 requests per hour, so having none is not an error.
    """
    tokens = access_tokens(nix_exe)
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


def get_latest_release(
    client: httpx2.Client, nix_exe: str, owner: str, repo: str
) -> str | None:
    """The latest release tag from the GitHub API, or None if there is none.

    Any failure answers None rather than raising: unauthenticated runs hit the
    rate limit and archived repos have no release, neither of which should stop
    the remaining inputs from being updated."""
    token = github_token(nix_exe, owner, repo)

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
        tags = pool.map(
            lambda repo: get_latest_release(client, cfg.nix_exe, *repo), repos
        )

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


def commit_pkgs(git_exe: str, message: str) -> None:
    """Commit anything that changed under pkgs/, if anything did."""
    status = subprocess_stdout([git_exe, "status", "--porcelain", "--", "pkgs/"])

    if not status:
        typer.echo("No pkgs/ changes to commit.", err=True)
        return

    run_logged([git_exe, "add", "--all", "--", "pkgs/"])
    run_logged([git_exe, "commit", "-m", message, "--", "pkgs/"])


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

    nix_cmd = nix_argv(cfg.nix_exe, "flake", "update" if update else "lock")
    if commit:
        nix_cmd.append("--commit-lock-file")
    run_logged(nix_cmd)

    # Amend into nix's lockfile commit to preserve its auto-generated message.
    if commit and flake_changed:
        run_logged([cfg.git_exe, "commit", "--amend", "--no-edit", str(flake_file)])

    if cfg.hash_path:
        # `fix hashes` repairs what nix journaled while building, so the build is
        # what gives it anything to do and its failure is the point. `.` re-resolves
        # the working tree; `cfg.flake` predates the lockfile rewritten above.
        hashed = nix_eval_targets(cfg.nix_exe, f".#{cfg.hash_path}")
        build_targets(cfg.nix_exe, hashed, check=False)

    # Non-zero also means "nothing to fix".
    run_logged([cfg.nixd_exe, "fix", "hashes", "--auto-apply"], check=False)

    if commit:
        commit_pkgs(cfg.git_exe, "chore(deps/pkgs): hashing")


@app.command(
    "check-build",
    context_settings={"allow_extra_args": True, "ignore_unknown_options": True},
)
def check_build(
    ctx: typer.Context,
    path: Annotated[str | None, typer.Option("--path", "-p")] = None,
    workers: EvalWorkers = EVAL_WORKERS,
    max_memory_size: EvalMaxMemorySize = EVAL_MAX_MEMORY_SIZE,
):
    """Build the CI targets of a flake attribute path that no binary cache holds.

    Extra arguments go to nix-fast-build, which builds each target as soon as it
    has evaluated. Its nix-eval-jobs workers are bounded as in `check-flake`,
    which evaluates everything else.
    """
    cfg: Config = ctx.obj
    path = path or cfg.build_path

    if not path:
        typer.echo("Specify --path or set --build-path.", err=True)
        raise typer.Exit(1)

    run_logged(
        [
            cfg.nix_fast_build_exe,
            "--nix",
            cfg.nix_exe,
            "--nix-build",
            str(Path(cfg.nix_exe).with_name("nix-build")),
            "--nix-eval-jobs",
            cfg.nix_eval_jobs_exe,
            "--flake",
            f"{cfg.flake}#{path}",
            "--select",
            BUILD_SELECT,
            "--eval-workers",
            str(workers),
            "--eval-max-memory-size",
            str(max_memory_size),
            "--skip-cached",
            *ctx.args,
        ]
    )


def write_step_summary(passed: Sequence[str], failed: Mapping[str, str]) -> None:
    """Append the evaluation results to the job summary, as nix-fast-build does."""
    summary = os.environ.get("GITHUB_STEP_SUMMARY")

    if not summary:
        return

    status = (
        f"## ❌ Evaluation Failed ({len(failed)} failed, {len(passed)} successful)"
        if failed
        else f"## ✅ All Evaluations Passed ({len(passed)} successful)"
    )
    lines = ["# nix-eval-jobs Results", "", status, ""]

    for attr, error in failed.items():
        lines += [f"**`{attr}`**", "", "```", error.strip(), "```", ""]

    lines += [
        "<details>",
        f"<summary>Evaluated {len(passed)} attributes</summary>",
        "",
        *(f"- {attr}" for attr in passed),
        "</details>",
        "",
    ]

    with Path(summary).open("a") as file:
        file.write("\n".join(lines))


def eval_jobs(cfg: Config, workers: int, max_memory_size: int) -> bool:
    """Evaluate `EVAL_SELECT` with nix-eval-jobs, reporting each failing attribute.

    A worker is restarted once it exceeds `max_memory_size` MiB, which keeps the
    peak at `workers * max_memory_size` however many configurations the flake has.
    """
    passed: list[str] = []
    failed: dict[str, str] = {}

    with tempfile.TemporaryDirectory() as gc_roots:
        cmd = [
            cfg.nix_eval_jobs_exe,
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
        typer.echo(f"nix-eval-jobs --flake {cfg.flake}", err=True)

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

    write_step_summary(passed, failed)

    return proc.returncode == 0 and not failed


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

    failed = run_logged(nix_argv(cfg.nix_exe, "fmt", "--", "--ci"), check=False) != 0

    apps = subprocess_capture(
        nix_argv(
            cfg.nix_exe, "eval", "--json", f"{cfg.flake}#.apps", "--apply", APPS_APPLY
        )
    )

    if apps.returncode:
        failed = True
        typer.echo(apps.stderr.rstrip(), err=True)

    failed |= not eval_jobs(cfg, workers, max_memory_size)

    if failed:
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
    nix_exe: str,
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
            nix_exe,
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
    nix_exe: str, update_scripts_nix: str, attr_path: str, packages: Iterable[str]
) -> dict[str, PackageMeta]:
    """Current metadata for the updateScript `packages` under `attr_path`.

    Evaluates the `metadata` output, which forces only each version and
    changelog and so realizes nothing (unlike the manifest).
    """
    entries = nix_eval_json(
        nix_exe,
        "--impure",
        *update_scripts_args(update_scripts_nix, "metadata", attr_path, packages),
    )

    return {key: PackageMeta(**fields) for key, fields in entries.items()}


def format_bump(key: str, old_version: str, meta: PackageMeta) -> str:
    """One commit-body line, linked to the changelog where the package has one."""
    bump = f"{key}: {old_version} -> {meta.version}"

    return f"- [{bump}]({meta.changelog})" if meta.changelog else f"- {bump}"


def revert_pkgs(git_exe: str, scripts: Iterable[UpdateScript]) -> None:
    """Restore each package's source from git, discarding a broken or partial
    update so it is never kept or committed."""
    sources = sorted({p for s in scripts if (p := s.path)})

    if not sources:
        return

    typer.echo(f"Reverting {len(sources)} package(s): {', '.join(sources)}", err=True)
    run_logged([git_exe, "restore", "--", *sources])


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
        cfg.nix_exe,
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

    succeeded: set[str] = set()

    with concurrent.futures.ThreadPoolExecutor(
        max_workers=min(len(scripts), cfg.max_workers)
    ) as pool:
        # Tokens resolve here rather than in `run` so the cached `access-tokens`
        # lookup happens once, on this thread, instead of racing across workers.
        futures = {
            pool.submit(
                script.run, github_token(cfg.nix_exe, *script.github_scope)
            ): key
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
    revert_pkgs(cfg.git_exe, [scripts[key] for key in failures])

    if commit:
        # List every version bump in the commit body (sorted), à la `nix flake update`.
        updated = (
            eval_metadata(
                cfg.nix_exe, cfg.update_scripts_nix, cfg.update_path, succeeded
            )
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

        commit_pkgs(cfg.git_exe, message)

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
