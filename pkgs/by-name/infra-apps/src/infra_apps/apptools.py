"""Helpers shared by the Python apps of this repository, packaged with `mkPythonApp`."""

import json
import os
import shlex
import subprocess
import sys
from argparse import (
    ArgumentDefaultsHelpFormatter,
    ArgumentParser,
    RawDescriptionHelpFormatter,
    _SubParsersAction,
)
from collections.abc import Callable, Container, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any, NoReturn

__all__ = [
    "CommandError",
    "ConfigOption",
    "Error",
    "HelpFormatter",
    "add_command",
    "complete",
    "entrypoint",
    "run",
    "run_json",
    "run_nul",
]


class Error(Exception):
    """An error shown to the user without a traceback, exiting with its code."""

    exit_code = 1


class CommandError(Error):
    """A command that failed, exiting with its code and its standard error if captured."""

    def __init__(self, args: Sequence[str | Path], code: int, stderr: str) -> None:
        """Describe the command by its first two arguments, the later ones may span lines."""
        self.stderr = stderr.strip()
        detail = f": {self.stderr}" if self.stderr else ""
        command = shlex.join(map(str, args[:2]))
        super().__init__(f"`{command}` exited with code {code}{detail}")
        self.exit_code = code


def run(
    *args: str | Path,
    codes: Container[int] = (0,),
    capture: bool = False,
    output: bool = True,
    stdin: str | None = None,
    env: Mapping[str, str] | None = None,
) -> str:
    """Run a command and return its standard output, capturing its standard error if asked.

    Without `output`, the standard output goes to the terminal instead and the result is empty.
    """
    process = subprocess.run(
        args,
        check=False,
        input=stdin,
        env=env,
        stdout=subprocess.PIPE if output else None,
        stderr=subprocess.PIPE if capture else None,
        text=True,
    )

    if process.returncode not in codes:
        raise CommandError(args, process.returncode, process.stderr or "")

    return process.stdout or ""


def run_json(
    *args: str | Path,
    codes: Container[int] = (0,),
    capture: bool = False,
    stdin: str | None = None,
) -> Any:
    """Run a command and return its standard output parsed as JSON."""
    output = run(*args, codes=codes, capture=capture, stdin=stdin)

    try:
        return json.loads(output)
    except json.JSONDecodeError as error:
        command = shlex.join(map(str, args[:2]))
        raise Error(f"`{command}` printed no JSON: {error}") from error


def run_nul(*args: str | Path) -> list[str]:
    """Run a command printing null-separated entries, such as `git ls-files -z`, and return them."""
    return [entry for entry in run(*args).split("\0") if entry]


class HelpFormatter(RawDescriptionHelpFormatter, ArgumentDefaultsHelpFormatter):
    """Keep the paragraphs of docstrings and show the defaults of options."""


def add_command(
    commands: _SubParsersAction[ArgumentParser],
    name: str,
    doc: str | None,
    *,
    parents: Sequence[ArgumentParser] = (),
    add_help: bool = True,
) -> ArgumentParser:
    """Add a command documented by a docstring, whose first line summarizes it."""
    doc = doc or ""

    return commands.add_parser(
        name,
        help=doc.partition("\n")[0],
        description=doc,
        parents=parents,
        formatter_class=HelpFormatter,
        allow_abbrev=False,
        add_help=add_help,
    )


@dataclass(frozen=True, slots=True)
class ConfigOption[T]:
    """A `--config` file parsed ahead of the other arguments, which may depend on it.

    So the config can supply the choices of the parser, which the shell completions offer as well.
    """

    load: Callable[[Any], T]
    default: T
    help: str

    def parser(self) -> ArgumentParser:
        """A parent parser of the option, for the parser of the command line, which `parse` reads."""
        parser = ArgumentParser(add_help=False)
        parser.add_argument("--config", type=Path, help=self.help)

        return parser

    def parse(self) -> T:
        """The config of the command line, loaded from its JSON, ignoring the other arguments."""
        path: Path | None = self.parser().parse_known_args()[0].config

        return self.default if path is None else self.load(json.loads(path.read_text()))


def complete(parser: ArgumentParser) -> ArgumentParser:
    """Answer the shell when it completes the command line, otherwise return the parser.

    `mkPythonApp` installs the completions of the shells, which run the app to complete.
    """
    if "_ARGCOMPLETE" in os.environ:
        import argcomplete

        argcomplete.autocomplete(parser)

    return parser


def entrypoint(main: Callable[[], int | None]) -> Callable[[], NoReturn]:
    """Decorate the main function of an app to exit with the code it returns.

    Errors and interrupts show without a traceback.
    """

    def run() -> NoReturn:
        try:
            code = main()
        except Error as error:
            print(f"Error: {error}", file=sys.stderr)
            raise SystemExit(error.exit_code) from None
        except (EOFError, KeyboardInterrupt):
            print("\nAborted!", file=sys.stderr)
            raise SystemExit(1) from None

        raise SystemExit(code)

    return run
