import json
import shlex
import subprocess
from collections.abc import Iterable
from pathlib import Path
from typing import Annotated, Any

import typer

EXPERIMENTAL_FLAGS = ["--extra-experimental-features", "nix-command flakes"]

app = typer.Typer(
    add_completion=False,
    pretty_exceptions_enable=False,
)


def subprocess_stdout(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)

    try:
        result.check_returncode()
    except subprocess.CalledProcessError as e:
        typer.echo(e.stderr, err=True)
        raise typer.Exit(1) from e

    return result.stdout.strip()


def nix_eval_attr(nix_exe: str, flake: str, attribute: str) -> dict[str, str]:
    expr = f"{flake}#{attribute}"
    entries = json.loads(
        subprocess_stdout(
            [
                nix_exe,
                *EXPERIMENTAL_FLAGS,
                "eval",
                "--json",
                expr,
            ]
        )
    )

    if not isinstance(entries, dict) or not all(
        isinstance(key, str)
        and isinstance(value, str)
        and value.startswith("/nix/store/")
        for key, value in entries.items()
    ):
        typer.echo(
            f"{expr} did not evaluate to an attrset of package store paths", err=True
        )
        raise typer.Exit(1)

    return entries


def nix_path_info(nix_exe: str, cache: str, paths: Iterable[str]) -> dict[str, Any]:
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


@app.command(
    context_settings={
        "allow_extra_args": True,
        "ignore_unknown_options": True,
    }
)
def run(
    ctx: typer.Context,
    nix_exe: Annotated[str, typer.Option()],
    flake: Annotated[str, typer.Option()],
    cache: str = "https://mirkolenz.cachix.org",
    attribute: str = "ciTargets",
    dry_run: bool = False,
):
    typer.echo("Discovering packages...", err=True)

    pkgs2path = nix_eval_attr(nix_exe, flake, attribute)
    paths2pkg = {value: key for key, value in pkgs2path.items()}

    if pkgs2path:
        typer.echo(
            f"Found {len(pkgs2path)} packages in {flake}#{attribute}: {', '.join(pkgs2path.keys())}.",
            err=True,
        )
    else:
        typer.echo(f"Found no packages in {flake}#{attribute}.", err=True)
        raise typer.Exit(0)

    pkgs_info = nix_path_info(nix_exe, cache, pkgs2path.values())

    pkgs_uncached = [
        paths2pkg[key] for key, value in pkgs_info.items() if value is None
    ]

    if pkgs_uncached:
        typer.echo(
            f"Found {len(pkgs_uncached)} uncached packages: {', '.join(pkgs_uncached)}.",
            err=True,
        )
    else:
        typer.echo("Found no uncached packages.", err=True)
        raise typer.Exit(0)

    refs_uncached = [f'{flake}#"{key}"' for key in pkgs_uncached]

    cmd: list[str] = [
        nix_exe,
        *EXPERIMENTAL_FLAGS,
        "build",
        *refs_uncached,
        *ctx.args,
    ]

    typer.echo(
        shlex.join([Path(cmd[0]).name, *cmd[1:]]),
        err=True,
    )

    if not dry_run:
        cmd_res = subprocess.run(cmd)
        raise typer.Exit(cmd_res.returncode)


if __name__ == "__main__":
    app()
