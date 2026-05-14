import json
import re
import shlex
import subprocess
from collections.abc import Iterable
from pathlib import Path
from typing import Annotated

import typer

app = typer.Typer(
    add_completion=False,
    pretty_exceptions_enable=False,
)

# Match github inputs whose ref contains a full semver (major.minor.patch),
# allowing arbitrary prefix/suffix around it (e.g. v1.2.3, release-1.2.3-rc1).
PATTERN = re.compile(
    r'url = "github:(?P<owner>[^/"]+)/(?P<repo>[^/"]+)/(?P<ref>[^/"]*\d+\.\d+\.\d+[^/"]*)"'
)

EXPERIMENTAL_FLAGS = ["--extra-experimental-features", "nix-command flakes"]


def subprocess_stdout(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    try:
        result.check_returncode()
    except subprocess.CalledProcessError as e:
        typer.echo(e.stderr, err=True)
        raise typer.Exit(1) from e
    return result.stdout.strip()


def run_logged(cmd: list[str], *, check: bool = True) -> None:
    typer.echo(shlex.join([Path(cmd[0]).name, *cmd[1:]]), err=True)
    subprocess.run(cmd, check=check)


def get_latest_release(gh_exe: str, owner: str, repo: str) -> str | None:
    """Fetch the latest release tag via the gh CLI."""
    result = subprocess.run(
        [
            gh_exe,
            "api",
            f"repos/{owner}/{repo}/releases/latest",
            "--jq",
            ".tag_name",
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        return None

    return result.stdout.strip() or None


def replace_match(gh_exe: str, match: re.Match[str]) -> str:
    owner = match.group("owner")
    repo = match.group("repo")
    current_ref = match.group("ref")

    latest = get_latest_release(gh_exe, owner, repo)

    if latest is None:
        typer.echo(f"{owner}/{repo}: no release found", err=True)
        return match.group(0)

    if latest == current_ref:
        typer.echo(f"{owner}/{repo}: up to date ({current_ref})", err=True)
        return match.group(0)

    typer.echo(f"{owner}/{repo}: {current_ref} -> {latest}", err=True)

    return f'url = "github:{owner}/{repo}/{latest}"'


def nix_eval_out_paths(nix_exe: str, packages: list[str]) -> dict[str, str]:
    names = json.dumps(packages)
    expr = (
        "let "
        "  flake = builtins.getFlake (toString ./.); "
        "  pkgs = flake.packages.${builtins.currentSystem}; "
        f"in builtins.listToAttrs (map (n: {{ name = n; value = pkgs.${{n}}.outPath; }}) {names})"
    )
    entries = json.loads(
        subprocess_stdout([
            nix_exe,
            *EXPERIMENTAL_FLAGS,
            "eval",
            "--json",
            "--impure",
            "--expr",
            expr,
        ])
    )
    if not isinstance(entries, dict):
        typer.echo("Failed to evaluate package out paths", err=True)
        raise typer.Exit(1)
    return entries


def nix_path_info(
    nix_exe: str, cache: str, paths: Iterable[str]
) -> dict[str, object]:
    entries = json.loads(
        subprocess_stdout([
            nix_exe,
            *EXPERIMENTAL_FLAGS,
            "path-info",
            "--json",
            "--store",
            cache,
            *paths,
        ])
    )
    if not isinstance(entries, dict):
        typer.echo(f"Failed to query cache {cache}", err=True)
        raise typer.Exit(1)
    return entries


def ensure_built(nix_exe: str, cache: str, packages: list[str]) -> None:
    """Build any of the requested packages that are not already in the cache."""
    paths = nix_eval_out_paths(nix_exe, packages)
    info = nix_path_info(nix_exe, cache, paths.values())
    uncached = [name for name, path in paths.items() if info.get(path) is None]

    if not uncached:
        typer.echo(
            f"All {len(packages)} requested package(s) are available from {cache}.",
            err=True,
        )
        return

    typer.echo(
        f"Building {len(uncached)} uncached package(s): {', '.join(uncached)}.",
        err=True,
    )
    refs = [f'.#"{name}"' for name in uncached]
    # Tolerate build failures — fix-hashes runs next and may resolve them.
    run_logged([nix_exe, *EXPERIMENTAL_FLAGS, "build", *refs], check=False)


def commit_pkgs(git_exe: str, message: str) -> None:
    """Commit anything that changed under pkgs/, if anything did."""
    status = subprocess.run(
        [git_exe, "status", "--porcelain", "--", "pkgs/"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    if not status:
        typer.echo("No pkgs/ changes to commit.", err=True)
        return

    run_logged([git_exe, "add", "--all", "--", "pkgs/"])
    run_logged([git_exe, "commit", "-m", message, "--", "pkgs/"])


@app.command()
def run(
    gh_exe: Annotated[str, typer.Option()],
    git_exe: Annotated[str, typer.Option()],
    nix_exe: Annotated[str, typer.Option()],
    nixd_exe: Annotated[str, typer.Option()] = "determinate-nixd",
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
    package: Annotated[
        list[str] | None,
        typer.Option(
            "--package",
            "-p",
            help="Package name to ensure is built before fix-hashes (repeatable).",
        ),
    ] = None,
    cache: Annotated[str, typer.Option()] = "https://mirkolenz.cachix.org",
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
    commit: Annotated[bool, typer.Option("--commit", "-c")] = False,
    update: Annotated[bool, typer.Option("--update", "-u")] = True,
):
    """Update flake.nix inputs and lockfile, build pinned packages, run
    determinate-nixd fix hashes, and optionally commit pkgs/."""
    content = flake_file.read_text()
    new_content = PATTERN.sub(lambda m: replace_match(gh_exe, m), content)

    if dry_run:
        typer.echo("Dry run, no changes written", err=True)
        raise typer.Exit(0)

    flake_changed = new_content != content
    if flake_changed:
        flake_file.write_text(new_content)
    else:
        typer.echo("No changes needed", err=True)

    nix_cmd = [nix_exe, "flake", "update" if update else "lock"]
    if commit:
        nix_cmd.append("--commit-lock-file")
    run_logged(nix_cmd)

    # Amend into nix's lockfile commit to preserve its auto-generated message.
    if commit and flake_changed:
        run_logged([git_exe, "commit", "--amend", "--no-edit", str(flake_file)])

    if package:
        ensure_built(nix_exe, cache, package)

    run_logged([nixd_exe, "fix", "hashes", "--auto-apply"])

    if commit:
        commit_pkgs(git_exe, "chore(pkgs): auto-fix hashes")


if __name__ == "__main__":
    app()
