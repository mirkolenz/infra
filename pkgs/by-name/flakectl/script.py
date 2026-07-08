import concurrent.futures
import functools
import getpass
import json
import os
import re
import shlex
import subprocess
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated, Any

import typer

# Flags passed to every `nix` invocation.
NIX_FLAGS = ["--extra-experimental-features", "nix-command flakes"]

# Match github inputs pinned to a semver ref (e.g. v1.2.3, release-1.2.3-rc1).
GITHUB_SEMVER_REF = re.compile(
    r'url = "github:(?P<owner>[^/"]+)/(?P<repo>[^/"]+)/(?P<ref>[^/"]*\d+\.\d+\.\d+[^/"]*)"'
)


@dataclass(frozen=True, slots=True)
class Config:
    flake: str
    nix_exe: str
    git_exe: str
    gh_exe: str
    update_scripts_nix: str | None
    nixd_exe: str
    darwin_builder: str
    linux_builder: str
    home_builder: str
    cache: str | None
    impure_attr: str | None
    build_path: str | None
    hash_path: str | None
    update_path: str | None
    max_workers: int


def subprocess_stdout(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)

    try:
        result.check_returncode()
    except subprocess.CalledProcessError as e:
        typer.echo(e.stderr, err=True)
        raise typer.Exit(1) from e

    return result.stdout.strip()


def run_logged(cmd: list[str], *, check: bool = True) -> int:
    """Log `cmd` (basename argv0, leading NIX_FLAGS elided) then run it; return its returncode."""
    head, *tail = cmd

    if tail[: len(NIX_FLAGS)] == NIX_FLAGS:
        tail = tail[len(NIX_FLAGS) :]

    typer.echo(shlex.join([Path(head).name, *tail]), err=True)

    return subprocess.run(cmd, check=check).returncode


def nix_argv(nix_exe: str, *args: str) -> list[str]:
    """Build a `nix` argv with the standard flags prepended."""
    return [nix_exe, *NIX_FLAGS, *args]


def nix_eval_json(nix_exe: str, *args: str) -> Any:
    """Evaluate a nix expression to JSON and parse it."""
    return json.loads(subprocess_stdout(nix_argv(nix_exe, "eval", "--json", *args)))


def nix_eval_dict(nix_exe: str, *args: str) -> dict[str, str]:
    """Evaluate a nix expression and assert it returns `{name: store_path}`."""
    entries = nix_eval_json(nix_exe, *args)

    if not isinstance(entries, dict) or not all(
        isinstance(k, str) and isinstance(v, str) and v.startswith("/nix/store/")
        for k, v in entries.items()
    ):
        typer.echo(
            f"nix eval {shlex.join(args)} did not return an attrset of store paths",
            err=True,
        )
        raise typer.Exit(1)

    return entries


def path_in_cache(nix_exe: str, cache: str, path: str) -> bool:
    """Whether `path` is present in the binary `cache` itself.

    Substituters are disabled so the exit code reflects true membership of
    `cache`, not whether some other cache could supply the path."""
    return (
        subprocess.run(
            nix_argv(
                nix_exe, "path-info", "--store", cache, "--substituters", "", path
            ),
            capture_output=True,
        ).returncode
        == 0
    )


def cached_paths(
    nix_exe: str, cache: str, paths: Iterable[str], max_workers: int
) -> set[str]:
    """Return the subset of `paths` already present in the binary `cache`.

    A single `nix path-info --store <cache>` aborts on the first path it cannot
    resolve, so query each path on its own via `path_in_cache` and keep the ones
    that are present."""
    paths = list(paths)

    if not paths:
        return set()

    # Probe reachability first: otherwise an unreachable cache reads as every
    # path missing and silently rebuilds everything instead of failing loudly.
    if subprocess.run(
        nix_argv(nix_exe, "store", "info", "--store", cache), capture_output=True
    ).returncode:
        typer.echo(f"Cache {cache} is unreachable.", err=True)
        raise typer.Exit(1)

    check = functools.partial(path_in_cache, nix_exe, cache)

    with concurrent.futures.ThreadPoolExecutor(
        max_workers=min(len(paths), max_workers)
    ) as pool:
        return {path for path, ok in zip(paths, pool.map(check, paths)) if ok}


def build_uncached(
    nix_exe: str,
    flake: str,
    cache: str | None,
    pkgs2path: dict[str, str],
    max_workers: int,
    extra: Sequence[str] = (),
    *,
    check: bool = True,
) -> list[str]:
    """Build any of `pkgs2path` not yet present in `cache`; return their names."""
    if cache:
        cached = cached_paths(nix_exe, cache, pkgs2path.values(), max_workers)
        uncached = [name for name, path in pkgs2path.items() if path not in cached]
    else:
        uncached = list(pkgs2path.keys())

    if not uncached:
        typer.echo(f"All {len(pkgs2path)} package(s) available from {cache}.", err=True)
        return uncached

    typer.echo(
        f"Building {len(uncached)} uncached package(s): {', '.join(uncached)}.",
        err=True,
    )
    refs = [f'{flake}#"{name}"' for name in uncached]
    run_logged(nix_argv(nix_exe, "build", *refs, *extra), check=check)
    return uncached


app = typer.Typer(
    add_completion=False,
    pretty_exceptions_enable=False,
    help="Unified toolkit for managing a NixOS flake.",
)


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    nix_exe: Annotated[str, typer.Option()] = "nix",
    git_exe: Annotated[str, typer.Option()] = "git",
    gh_exe: Annotated[str, typer.Option()] = "gh",
    update_scripts_nix: Annotated[str | None, typer.Option()] = None,
    nixd_exe: Annotated[str, typer.Option()] = "determinate-nixd",
    darwin_builder: Annotated[str, typer.Option()] = "darwin-rebuild",
    linux_builder: Annotated[str, typer.Option()] = "nixos-rebuild",
    home_builder: Annotated[str, typer.Option()] = "home-manager",
    flake: Annotated[str, typer.Option()] = ".",
    cache: Annotated[str | None, typer.Option()] = None,
    impure_attr: Annotated[str | None, typer.Option()] = None,
    build_path: Annotated[str | None, typer.Option()] = None,
    hash_path: Annotated[str | None, typer.Option()] = None,
    update_path: Annotated[str | None, typer.Option()] = None,
    max_workers: Annotated[int, typer.Option()] = 8,
):
    ctx.obj = Config(**ctx.params)
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
            cfg.nix_exe, f'{cfg.flake}#{attr}."{name}".{cfg.impure_attr}'
        )

    cmd: list[str] = [builder, operation, "--flake", f"{cfg.flake}#{name}"]

    if is_impure:
        cmd.append("--impure")

    cmd.extend(ctx.args)

    raise typer.Exit(run_logged(cmd, check=False))


def get_latest_release(gh_exe: str, owner: str, repo: str) -> str | None:
    """Fetch the latest release tag via the gh CLI."""
    result = subprocess.run(
        [gh_exe, "api", f"repos/{owner}/{repo}/releases/latest", "--jq", ".tag_name"],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        return None

    return result.stdout.strip() or None


def replace_github_ref(gh_exe: str, match: re.Match[str]) -> str:
    owner = match.group("owner")
    repo = match.group("repo")
    current = match.group("ref")
    latest = get_latest_release(gh_exe, owner, repo)

    if latest is None:
        typer.echo(f"{owner}/{repo}: no release found", err=True)
        return match.group(0)
    if latest == current:
        typer.echo(f"{owner}/{repo}: up to date ({current})", err=True)
        return match.group(0)

    typer.echo(f"{owner}/{repo}: {current} -> {latest}", err=True)
    return f'url = "github:{owner}/{repo}/{latest}"'


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
    flake_file: Annotated[
        Path,
        typer.Argument(
            exists=True,
            file_okay=True,
            dir_okay=False,
            readable=True,
            writable=True,
        ),
    ] = Path("flake.nix"),
    path: Annotated[
        str | None,
        typer.Option(
            "--path",
            "-p",
            help="Attribute path of packages to build before fix-hashes.",
        ),
    ] = None,
    cache: Annotated[str | None, typer.Option()] = None,
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
    commit: Annotated[bool, typer.Option("--commit", "-c")] = False,
    update: Annotated[bool, typer.Option("--update", "-u")] = True,
):
    """Update flake.nix github inputs and lockfile; refresh pinned hashes."""
    cfg: Config = ctx.obj
    path = path or cfg.hash_path
    cache = cache or cfg.cache
    content = flake_file.read_text()
    new_content = GITHUB_SEMVER_REF.sub(
        lambda m: replace_github_ref(cfg.gh_exe, m), content
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

    # Fail fast: forcing the package set surfaces a broken input/override as one
    # clear error here instead of a cascade downstream and in the PR's checks.
    if cfg.update_path and cfg.update_scripts_nix:
        typer.echo("Verifying the updated flake still evaluates...", err=True)
        subprocess_stdout(
            nix_argv(
                cfg.nix_exe,
                "eval",
                "--impure",
                *update_scripts_args(cfg.update_scripts_nix, "names", cfg.update_path),
            )
        )

    run_fix_hashes = True

    if path:
        pkgs2path = nix_eval_dict(cfg.nix_exe, f"{cfg.flake}#{path}")
        # Tolerate build failures — fix-hashes runs next and may resolve them.
        uncached = build_uncached(
            cfg.nix_exe, cfg.flake, cache, pkgs2path, cfg.max_workers, check=False
        )
        run_fix_hashes = bool(uncached)

    if run_fix_hashes:
        run_logged([cfg.nixd_exe, "fix", "hashes", "--auto-apply"])

        if commit:
            commit_pkgs(cfg.git_exe, "chore(deps/pkgs): hashing")


@app.command(
    "build-pkgs",
    context_settings={"allow_extra_args": True, "ignore_unknown_options": True},
)
def build_pkgs(
    ctx: typer.Context,
    path: Annotated[str | None, typer.Option("--path", "-p")] = None,
    cache: Annotated[str | None, typer.Option()] = None,
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
):
    """Build packages from a flake attribute path that aren't in the cache yet."""
    cfg: Config = ctx.obj
    path = path or cfg.build_path
    cache = cache or cfg.cache

    if not path:
        typer.echo("Specify --path or set --build-path.", err=True)
        raise typer.Exit(1)

    typer.echo("Discovering packages...", err=True)
    pkgs2path = nix_eval_dict(cfg.nix_exe, f"{cfg.flake}#{path}")

    if not pkgs2path:
        typer.echo(f"Found no packages in {cfg.flake}#{path}.", err=True)
        raise typer.Exit(0)

    typer.echo(
        f"Found {len(pkgs2path)} packages in {cfg.flake}#{path}: "
        f"{', '.join(pkgs2path.keys())}.",
        err=True,
    )

    if dry_run:
        raise typer.Exit(0)

    build_uncached(cfg.nix_exe, cfg.flake, cache, pkgs2path, cfg.max_workers, ctx.args)


@dataclass(frozen=True, slots=True)
class UpdateScript:
    """A package's resolved `passthru.updateScript` (see update-scripts.nix)."""

    attr_path: str
    name: str
    pname: str
    old_version: str
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

    def run(self) -> subprocess.CompletedProcess[str]:
        """Run the updateScript, inheriting cwd (repo root) and PATH."""
        return subprocess.run(self.argv, capture_output=True, text=True)


def update_scripts_args(
    update_scripts_nix: str, output: str, attr_path: str
) -> list[str]:
    """`nix` args selecting `<output>` from update-scripts.nix for the working tree."""
    return [
        "-f",
        update_scripts_nix,
        output,
        "--argstr",
        "root",
        os.getcwd(),
        "--argstr",
        "path",
        attr_path,
    ]


def discover_update_scripts(
    nix_exe: str, update_scripts_nix: str, attr_path: str
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
            *update_scripts_args(update_scripts_nix, "manifest", attr_path),
            "--no-link",
            "--print-out-paths",
        )
    )

    return {
        key: UpdateScript(**fields)
        for key, fields in json.loads(Path(out).read_text()).items()
    }


def eval_versions(
    nix_exe: str, update_scripts_nix: str, attr_path: str
) -> dict[str, str]:
    """Current `{key: version}` for every updateScript package under `attr_path`.

    Evaluates the `versions` output, which forces only each version and so
    realizes nothing (unlike the manifest).
    """
    out = subprocess_stdout(
        nix_argv(
            nix_exe,
            "eval",
            "--impure",
            "--json",
            *update_scripts_args(update_scripts_nix, "versions", attr_path),
        )
    )

    return json.loads(out)


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

    if cfg.update_path is None or cfg.update_scripts_nix is None:
        typer.echo(
            "update-pkgs requires --update-path and --update-scripts-nix.", err=True
        )
        raise typer.Exit(1)

    typer.echo("Discovering updateScripts...", err=True)
    scripts = discover_update_scripts(
        cfg.nix_exe, cfg.update_scripts_nix, cfg.update_path
    )

    if package is not None:
        scripts = {k: v for k, v in scripts.items() if k == package}

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
        futures = {pool.submit(script.run): key for key, script in scripts.items()}

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
        new = eval_versions(cfg.nix_exe, cfg.update_scripts_nix, cfg.update_path)
        bumps = sorted(
            (key, s.old_version, new[key])
            for key, s in scripts.items()
            if key in succeeded and key in new and s.old_version != new[key]
        )
        message = "chore(deps/pkgs): update"

        if bumps:
            summary = "\n".join(
                f"- {key}: {old} -> {new_version}" for key, old, new_version in bumps
            )
            message += f"\n\nPackage updates:\n\n{summary}"

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
