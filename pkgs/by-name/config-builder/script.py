import json
import shlex
import subprocess
from pathlib import Path
from typing import Annotated

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


@app.command(
    context_settings={
        "allow_extra_args": True,
        "ignore_unknown_options": True,
        "help_option_names": ["--wrapper-help"],
    }
)
def run(
    ctx: typer.Context,
    nix_exe: Annotated[str, typer.Option()],
    flake: Annotated[str, typer.Option()],
    darwin_builder: Annotated[str, typer.Option()] = "darwin-rebuild",
    linux_builder: Annotated[str, typer.Option()] = "nixos-rebuild",
    home_builder: Annotated[str, typer.Option()] = "home-manager",
    operation: Annotated[
        str, typer.Option("--operation", "-o", "--mode", "-m")
    ] = "switch",
    name: Annotated[str | None, typer.Option("--name", "-n")] = None,
):
    node = subprocess_stdout(["uname", "-n"]).lower()
    kernel = subprocess_stdout(["uname", "-s"]).lower()
    user = subprocess_stdout(["whoami"]).lower()
    is_home = user != "root"

    if not name:
        name = f"{user}@{node}" if is_home else node

    if is_home:
        builder, flake_attribute = home_builder, "homeConfigurations"
    elif kernel == "darwin":
        builder, flake_attribute = darwin_builder, "darwinConfigurations"
    else:
        builder, flake_attribute = linux_builder, "nixosConfigurations"

    is_impure: bool = json.loads(
        subprocess_stdout(
            [
                nix_exe,
                *EXPERIMENTAL_FLAGS,
                "eval",
                "--json",
                f'{flake}#{flake_attribute}."{name}".config.custom.impureRebuild',
            ]
        )
    )

    cmd: list[str] = [builder, operation, "--flake", f"{flake}#{name}"]

    if is_impure:
        cmd.append("--impure")

    cmd.extend(ctx.args)

    typer.echo(
        shlex.join([Path(cmd[0]).name, *cmd[1:]]),
        err=True,
    )

    cmd_res = subprocess.run(cmd)
    raise typer.Exit(cmd_res.returncode)


if __name__ == "__main__":
    app()
