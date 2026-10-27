"""Format the files that coding agents edit with treefmt."""

import argparse
import json
import os
import signal
import subprocess
import sys
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import NotRequired, TypedDict

from infra_apps.apptools import HelpFormatter, add_command, entrypoint

# the headers of a Codex patch that precede the files it adds, updates, or moves to
PATCH_HEADERS = ("*** Add File: ", "*** Update File: ", "*** Move to: ")
# the length that the output of a failed run gets truncated to
MAX_OUTPUT = 2000
# below the timeout of the `PostToolUse` hook
TIMEOUT = 30


class ToolInput(TypedDict, total=False):
    """The input of an edit, a file of Claude Code or a patch of Codex."""

    file_path: str
    command: str


class Payload(TypedDict):
    """The payload of a `PostToolUse` hook of Claude Code or Codex."""

    cwd: str
    tool_input: NotRequired[ToolInput]


def repo_root(path: Path) -> Path | None:
    """The root of the git repository containing a directory, if any, where `.git` is a file in worktrees."""
    return next(
        (parent for parent in (path, *path.parents) if (parent / ".git").exists()), None
    )


@dataclass(frozen=True, slots=True)
class Treefmt:
    """The treefmt configuration, with the formatters that run on each edit, without the fixers."""

    config_file: Path
    formatters: str

    def run(self, root: Path, files: Iterable[Path]) -> str | None:
        """Format files below a root and return the output if it failed or timed out."""
        # a new session lets the formatters be killed with treefmt
        with subprocess.Popen(
            [
                "treefmt",
                f"--config-file={self.config_file}",
                f"--tree-root={root}",
                f"--formatters={self.formatters}",
                "--walk=filesystem",
                "--no-cache",
                "--quiet",
                "--on-unmatched=debug",
                *files,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            start_new_session=True,
        ) as process:
            try:
                output, _ = process.communicate(timeout=TIMEOUT)

            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                return f"treefmt timed out after {TIMEOUT} s"

        return output[:MAX_OUTPUT] if process.returncode else None

    def format(self, files: Iterable[Path]) -> str | None:
        """Format the files below their git repository, or else their directory, and return the failures."""
        roots: dict[Path, list[Path]] = {}

        for file in files:
            if file.is_file():
                file = file.resolve()
                roots.setdefault(repo_root(file.parent) or file.parent, []).append(file)

        failures = [
            output for root, group in roots.items() if (output := self.run(root, group))
        ]

        return "\n".join(failures) or None


def edited_files(cwd: Path, tool_input: ToolInput) -> Iterator[Path]:
    """The files edited by Claude Code, and by the patches of Codex."""
    if path := tool_input.get("file_path"):
        yield cwd / path

    for line in tool_input.get("command", "").splitlines():
        if line.startswith(PATCH_HEADERS):
            yield cwd / line.partition(": ")[2]


def hook(treefmt: Treefmt) -> None:
    """Handle the `PostToolUse` hook of Claude Code or Codex, reading its payload from standard input.

    Failures go to the agent.
    """
    payload: Payload = json.load(sys.stdin)
    edits = edited_files(Path(payload["cwd"]), payload.get("tool_input", {}))

    if failures := treefmt.format(edits):
        output = {"hookEventName": "PostToolUse", "additionalContext": failures}
        print(json.dumps({"hookSpecificOutput": output}))


def parser() -> argparse.ArgumentParser:
    """The parser of the command line."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=HelpFormatter)
    parser.add_argument("--config-file", type=Path, required=True)
    parser.add_argument("--formatters", required=True)
    commands = parser.add_subparsers(dest="command", required=True)
    files = add_command(
        commands, "files", "Format the files, exiting with the failures, for opencode."
    )
    files.add_argument("paths", nargs="+", type=Path)
    add_command(commands, "hook", hook.__doc__)

    return parser


@entrypoint
def main() -> None:
    """Parse the arguments and run the command."""
    args = parser().parse_args()
    treefmt = Treefmt(args.config_file, args.formatters)

    match args.command:
        case "files":
            # a message exits with code 1 after printing it to standard error
            sys.exit(treefmt.format(args.paths))

        case "hook":
            hook(treefmt)


if __name__ == "__main__":
    main()
