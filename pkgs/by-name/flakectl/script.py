import getpass
import json
import os
import re
import shlex
import subprocess
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Annotated

import typer

EXPERIMENTAL_FLAGS = ["--extra-experimental-features", "nix-command flakes"]

# Match github inputs whose ref contains a full semver (major.minor.patch),
# allowing arbitrary prefix/suffix (e.g. v1.2.3, release-1.2.3-rc1).
GITHUB_SEMVER_REF = re.compile(
    r'url = "github:(?P<owner>[^/"]+)/(?P<repo>[^/"]+)/(?P<ref>[^/"]*\d+\.\d+\.\d+[^/"]*)"'
)


@dataclass(frozen=True, slots=True)
class Config:
    flake: str
    nix_exe: str
    nix_shell_exe: str
    git_exe: str
    gh_exe: str
    nixd_exe: str
    darwin_builder: str
    linux_builder: str
    home_builder: str
    nixpkgs: str
    cache: str | None
    impure_attr: str | None
    update_overlays: str | None
    build_path: str | None
    hash_path: str | None
    update_path: str | None


def subprocess_stdout(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    try:
        result.check_returncode()
    except subprocess.CalledProcessError as e:
        typer.echo(e.stderr, err=True)
        raise typer.Exit(1) from e
    return result.stdout.strip()


def run_logged(cmd: list[str], *, check: bool = True) -> int:
    """Log `cmd` (executable shown by basename) then run it; return its returncode."""
    typer.echo(shlex.join([Path(cmd[0]).name, *cmd[1:]]), err=True)
    return subprocess.run(cmd, check=check).returncode


def nix_eval_dict(nix_exe: str, *args: str) -> dict[str, str]:
    """Evaluate a nix expression and assert it returns `{name: store_path}`."""
    entries = json.loads(
        subprocess_stdout([nix_exe, *EXPERIMENTAL_FLAGS, "eval", "--json", *args])
    )
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


def nix_path_info(nix_exe: str, cache: str, paths: Iterable[str]) -> dict[str, object]:
    entries = json.loads(
        subprocess_stdout(
            [
                nix_exe,
                *EXPERIMENTAL_FLAGS,
                "path-info",
                "--json",
                "--store",
                cache,
                *paths,
            ]
        )
    )
    if not isinstance(entries, dict):
        typer.echo(f"Failed to query cache {cache}", err=True)
        raise typer.Exit(1)
    return entries


def build_uncached(
    nix_exe: str,
    flake: str,
    cache: str | None,
    pkgs2path: dict[str, str],
    extra: Sequence[str] = (),
    *,
    check: bool = True,
) -> None:
    """Build any of `pkgs2path` not yet present in `cache`."""
    if cache:
        info = nix_path_info(nix_exe, cache, pkgs2path.values())
        uncached = [name for name, path in pkgs2path.items() if info.get(path) is None]
    else:
        uncached = list(pkgs2path.keys())

    if not uncached:
        typer.echo(f"All {len(pkgs2path)} package(s) available from {cache}.", err=True)
        return

    typer.echo(
        f"Building {len(uncached)} uncached package(s): {', '.join(uncached)}.",
        err=True,
    )
    refs = [f'{flake}#"{name}"' for name in uncached]
    run_logged([nix_exe, *EXPERIMENTAL_FLAGS, "build", *refs, *extra], check=check)


app = typer.Typer(
    add_completion=False,
    pretty_exceptions_enable=False,
    help="Unified toolkit for managing a NixOS flake.",
)


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    nixpkgs: Annotated[str, typer.Option()],
    nix_exe: Annotated[str, typer.Option()] = "nix",
    nix_shell_exe: Annotated[str, typer.Option()] = "nix-shell",
    git_exe: Annotated[str, typer.Option()] = "git",
    gh_exe: Annotated[str, typer.Option()] = "gh",
    nixd_exe: Annotated[str, typer.Option()] = "determinate-nixd",
    darwin_builder: Annotated[str, typer.Option()] = "darwin-rebuild",
    linux_builder: Annotated[str, typer.Option()] = "nixos-rebuild",
    home_builder: Annotated[str, typer.Option()] = "home-manager",
    flake: Annotated[str, typer.Option()] = ".",
    cache: Annotated[str | None, typer.Option()] = None,
    impure_attr: Annotated[str | None, typer.Option()] = None,
    update_overlays: Annotated[str | None, typer.Option()] = None,
    build_path: Annotated[str | None, typer.Option()] = None,
    hash_path: Annotated[str | None, typer.Option()] = None,
    update_path: Annotated[str | None, typer.Option()] = None,
):
    ctx.obj = Config(
        flake=flake,
        nix_exe=nix_exe,
        nix_shell_exe=nix_shell_exe,
        git_exe=git_exe,
        gh_exe=gh_exe,
        nixd_exe=nixd_exe,
        darwin_builder=darwin_builder,
        linux_builder=linux_builder,
        home_builder=home_builder,
        nixpkgs=nixpkgs,
        cache=cache,
        impure_attr=impure_attr,
        update_overlays=update_overlays,
        build_path=build_path,
        hash_path=hash_path,
        update_path=update_path,
    )
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

    is_impure: bool = False
    if cfg.impure_attr:
        is_impure = json.loads(
            subprocess_stdout(
                [
                    cfg.nix_exe,
                    *EXPERIMENTAL_FLAGS,
                    "eval",
                    "--json",
                    f'{cfg.flake}#{attr}."{name}".{cfg.impure_attr}',
                ]
            )
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

    nix_cmd = [cfg.nix_exe, *EXPERIMENTAL_FLAGS, "flake", "update" if update else "lock"]
    if commit:
        nix_cmd.append("--commit-lock-file")
    run_logged(nix_cmd)

    # Amend into nix's lockfile commit to preserve its auto-generated message.
    if commit and flake_changed:
        run_logged([cfg.git_exe, "commit", "--amend", "--no-edit", str(flake_file)])

    if path:
        pkgs2path = nix_eval_dict(cfg.nix_exe, f"{cfg.flake}#{path}")
        # Tolerate build failures — fix-hashes runs next and may resolve them.
        build_uncached(cfg.nix_exe, cfg.flake, cache, pkgs2path, check=False)

    run_logged([cfg.nixd_exe, "fix", "hashes", "--auto-apply"])

    if commit:
        commit_pkgs(cfg.git_exe, "chore(pkgs): auto-fix hashes")


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
        return

    build_uncached(cfg.nix_exe, cfg.flake, cache, pkgs2path, ctx.args)


class Order(StrEnum):
    TOPOLOGICAL = "topological"
    REVERSE_TOPOLOGICAL = "reverse-topological"


def _nix_arg(key: str, value: str | bool, raw: bool = False) -> list[str]:
    """Format a single `--arg`/`--argstr` pair for nix-shell."""
    if isinstance(value, bool):
        value = "true" if value else "false"
    return ["--arg" if raw else "--argstr", key, value]


# https://github.com/NixOS/nixpkgs/blob/master/maintainers/scripts/update.nix#L183
@app.command("update-pkgs")
def update_pkgs(
    ctx: typer.Context,
    maintainer: Annotated[str | None, typer.Option("--maintainer", "-m")] = None,
    package: Annotated[str | None, typer.Option("--package", "-p")] = None,
    predicate: Annotated[str | None, typer.Option("--predicate")] = None,
    path: Annotated[str | None, typer.Option("--path")] = None,
    max_workers: Annotated[int | None, typer.Option()] = None,
    keep_going: Annotated[bool, typer.Option()] = True,
    commit: Annotated[bool, typer.Option("--commit", "-c")] = False,
    prompt: Annotated[bool, typer.Option()] = False,
    order: Annotated[Order | None, typer.Option("--order", "-o")] = None,
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
):
    """Run nixpkgs maintainers/scripts/update.nix to refresh package sources."""
    cfg: Config = ctx.obj
    specs = sum(x is not None for x in [maintainer, package, predicate, path])

    if specs > 1:
        typer.echo(
            "Specify only one of maintainer / package / predicate / path.",
            err=True,
        )
        raise typer.Exit(1)
    if specs == 0 and cfg.update_path:
        path = cfg.update_path

    cmd: list[str] = [cfg.nix_shell_exe, f"{cfg.nixpkgs}/maintainers/scripts/update.nix"]
    if maintainer is not None:
        cmd += _nix_arg("maintainer", maintainer)
    if package is not None:
        cmd += _nix_arg("package", package)
    if predicate is not None:
        cmd += _nix_arg("predicate", predicate, raw=True)
    if path is not None:
        cmd += _nix_arg("path", path)
    if max_workers is not None:
        cmd += _nix_arg("max-workers", str(max_workers))
    if keep_going:
        cmd += _nix_arg("keep-going", True)
    if not prompt:
        cmd += _nix_arg("skip-prompt", True)
    if order is not None:
        cmd += _nix_arg("order", order.value)

    # Log before adding `include-overlays` (too noisy for the trace).
    typer.echo(
        shlex.join([Path(cmd[0]).name, Path(cmd[1]).name, *cmd[2:]]),
        err=True,
    )

    if cfg.update_overlays is not None:
        cmd += _nix_arg("include-overlays", cfg.update_overlays, raw=True)

    if dry_run:
        typer.echo("Dry run, no changes written", err=True)
        raise typer.Exit(0)

    result = subprocess.run(cmd)

    if result.returncode == 0 and commit:
        run_logged([cfg.git_exe, "commit", "-m", "chore(deps/pkgs): update", "./pkgs"])

    raise typer.Exit(result.returncode)


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
