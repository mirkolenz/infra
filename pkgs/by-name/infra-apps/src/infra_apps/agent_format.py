"""Format the files that coding agents edit with treefmt.

Each edit gets formatted, and at the end of a turn the changed files of the git repository get
fixed and formatted once more, since fixing mid-edit could drop an import that the next edit
is about to use. Remaining lints count as failures.
"""

import argparse
import json
import subprocess
import sys
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, NotRequired, TypedDict

from infra_apps.apptools import HelpFormatter, add_command, entrypoint, run_nul

# the headers of a Codex patch that precede the files it adds, updates, or moves to
PATCH_HEADERS = ("*** Add File: ", "*** Update File: ", "*** Move to: ")
# the length that the output of a failed run gets truncated to
MAX_OUTPUT = 2000


class ToolInput(TypedDict, total=False):
    """The input of an edit, a file of Claude Code or a patch of Codex."""

    file_path: str
    command: str


class Payload(TypedDict):
    """The payload of a hook of Claude Code or Codex."""

    hook_event_name: Literal["PostToolUse", "Stop"]
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

    def run(self, root: Path, files: Iterable[Path], *args: str) -> str | None:
        """Run treefmt on files below a root and return its output if it failed."""
        process = subprocess.run(
            [
                "treefmt",
                f"--config-file={self.config_file}",
                f"--tree-root={root}",
                "--walk=filesystem",
                "--no-cache",
                "--quiet",
                "--on-unmatched=debug",
                *args,
                *files,
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        return None if process.returncode == 0 else process.stdout[:MAX_OUTPUT]

    def format(self, files: Iterable[Path]) -> str | None:
        """Format the files below their git repository, or else their directory, and return the failures."""
        roots: dict[Path, list[Path]] = {}

        for file in files:
            if file.is_file():
                file = file.resolve()
                roots.setdefault(repo_root(file.parent) or file.parent, []).append(file)

        failures = [
            output
            for root, group in roots.items()
            if (output := self.run(root, group, f"--formatters={self.formatters}"))
        ]

        return "\n".join(failures) or None

    def fix(self, root: Path) -> str | None:
        """Fix and format the files of a git repository that differ from its head, including untracked ones, and return the failures."""
        git = ("git", "-C", root)
        paths = {
            *run_nul(*git, "diff", "-z", "--name-only", "--cached"),
            *run_nul(
                *git, "ls-files", "-z", "--modified", "--others", "--exclude-standard"
            ),
        }
        files = [file for path in paths if (file := root / path).is_file()]

        # without paths, treefmt would format the whole tree
        return self.run(root, files) if files else None


def edited_files(cwd: Path, tool_input: ToolInput) -> Iterator[Path]:
    """The files edited by Claude Code, and by the patches of Codex."""
    if path := tool_input.get("file_path"):
        yield cwd / path

    for line in tool_input.get("command", "").splitlines():
        if line.startswith(PATCH_HEADERS):
            yield cwd / line.partition(": ")[2]


def hook(treefmt: Treefmt) -> None:
    """Handle the `PostToolUse` or `Stop` hook of Claude Code or Codex, reading its payload from standard input.

    Failures of an edit go to the agent, those at the end of a turn to the user.
    """
    payload: Payload = json.load(sys.stdin)
    cwd = Path(payload["cwd"])

    match payload["hook_event_name"]:
        case "PostToolUse":
            edits = edited_files(cwd, payload.get("tool_input", {}))

            if failures := treefmt.format(edits):
                output = {"hookEventName": "PostToolUse", "additionalContext": failures}
                print(json.dumps({"hookSpecificOutput": output}))

        case "Stop":
            if (root := repo_root(cwd.resolve())) and (failures := treefmt.fix(root)):
                print(json.dumps({"systemMessage": failures}))


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
