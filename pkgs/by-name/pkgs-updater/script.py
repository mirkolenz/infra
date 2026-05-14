import shlex
import subprocess
from enum import StrEnum
from pathlib import Path
from typing import Annotated

import typer

app = typer.Typer(
    add_completion=False,
    pretty_exceptions_enable=False,
)


class Order(StrEnum):
    TOPOLOGICAL = "topological"
    REVERSE_TOPOLOGICAL = "reverse-topological"


def cmd_arg(key: str, value: str | bool, raw: bool = False) -> list[str]:
    """Convert an argument to a list of strings for Nix."""

    if isinstance(value, bool):
        value = "true" if value else "false"

    return ["--arg" if raw else "--argstr", key, value]


# https://github.com/NixOS/nixpkgs/blob/master/maintainers/scripts/update.nix#L183
@app.command()
def run(
    nixpkgs: Annotated[str, typer.Option()],
    nix_shell: Annotated[str, typer.Option()] = "nix-shell",
    maintainer: Annotated[str | None, typer.Option("--maintainer", "-m")] = None,
    package: Annotated[str | None, typer.Option("--package", "-p")] = None,
    function: Annotated[str | None, typer.Option("--function", "-f")] = None,
    attrset: Annotated[str | None, typer.Option("--attrset", "-a")] = None,
    max_workers: Annotated[int | None, typer.Option()] = None,
    keep_going: Annotated[bool, typer.Option()] = True,
    commit: Annotated[bool, typer.Option()] = False,
    prompt: Annotated[bool, typer.Option()] = False,
    order: Annotated[Order | None, typer.Option("--order", "-o")] = None,
    dry_run: Annotated[bool, typer.Option("--dry-run", "-n")] = False,
):
    specs = sum(x is not None for x in [maintainer, package, function, attrset])

    if specs > 1:
        typer.echo(
            "You can only specify one of maintainer, package, function, or attrset.",
            err=True,
        )
        raise typer.Exit(1)
    elif specs == 0:
        attrset = "custom.flattenedPackages"

    cmd: list[str] = [
        nix_shell,
        f"{nixpkgs}/maintainers/scripts/update.nix",
    ]

    if maintainer is not None:
        cmd += cmd_arg("maintainer", maintainer)

    if package is not None:
        cmd += cmd_arg("package", package)

    if function is not None:
        cmd += cmd_arg("predicate", function, raw=True)

    if attrset is not None:
        cmd += cmd_arg("path", attrset)

    if max_workers is not None:
        cmd += cmd_arg("max-workers", str(max_workers))

    if keep_going:
        cmd += cmd_arg("keep-going", True)

    # this would commit each package update separately, we use a global commit
    # if commit:
    #     cmd += cmd_arg("commit", True)

    if not prompt:
        cmd += cmd_arg("skip-prompt", True)

    if order is not None:
        cmd += cmd_arg("order", order.value)

    typer.echo(
        shlex.join([Path(cmd[0]).name, Path(cmd[1]).name, *cmd[2:]]),
        err=True,
    )

    overlays = """
        let
            flake = builtins.getFlake ("git+file://" + toString ./.);
            overlay = import ./pkgs flake.overlayArgs;
        in
        [ overlay ]
    """

    # we don't want to show this in the output
    cmd += cmd_arg("include-overlays", overlays, raw=True)

    if dry_run:
        typer.echo("Dry run, no changes written", err=True)
        raise typer.Exit(0)

    cmd_res = subprocess.run(cmd)

    if cmd_res.returncode == 0 and commit:
        git_cmd = ["git", "commit", "-m", "chore(deps/pkgs): update", "./pkgs"]

        typer.echo(
            shlex.join(git_cmd),
            err=True,
        )

        subprocess.run(git_cmd)

    raise typer.Exit(cmd_res.returncode)


if __name__ == "__main__":
    app()
