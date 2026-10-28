"""Replace the vendored copies of checkouts in the current project.

Only files tracked by git are copied, so the project can commit the copy instead of embedding
a repository. The top-level readme, license and `.gitignore` are left out, and the project keeps
its own.
"""

import argparse
import shutil
import sys
from collections.abc import Collection, Mapping
from pathlib import Path
from typing import TypedDict

from infra_apps.apptools import (
    ConfigOption,
    Error,
    HelpFormatter,
    complete,
    entrypoint,
    run_nul,
)

# the pathspecs of the top-level files that the project keeps its own of
EXCLUDES = (":(exclude,glob)README*", ":(exclude,glob)LICENSE*", ":(exclude).gitignore")


class ProjectFile(TypedDict):
    """A file of the project selecting the copy, with the path of its content."""

    name: str
    source: str


class Checkout(TypedDict):
    """A live checkout and the location of its copy in the project."""

    source: str
    target: str
    projectFile: ProjectFile | None


def checkouts(data: Mapping[str, Checkout]) -> dict[str, Checkout]:
    """The checkouts of a config, keyed by name."""
    return dict(data)


CONFIG = ConfigOption(checkouts, {}, "JSON file of the checkouts, keyed by name.")


def tracked_files(root: Path) -> list[str]:
    """The files tracked by git in a checkout, without those the project keeps its own of."""
    return run_nul("git", "-C", root, "ls-files", "-z", "--", *EXCLUDES)


def vendor(checkout: Checkout, force: bool) -> None:
    """Replace the copy of a checkout and write its project file unless it exists or is forced."""
    source = Path(checkout["source"])
    target = Path(checkout["target"])

    if not source.is_dir():
        raise Error(f"Checkout {source} is missing")

    if target.exists(follow_symlinks=False):
        shutil.rmtree(target)

    for path in tracked_files(source):
        file = source / path

        # tracked files deleted from the worktree, and directories of submodules, are skipped
        if file.is_symlink() or file.is_file():
            (target / path).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file, target / path, follow_symlinks=False)

    if (project_file := checkout["projectFile"]) is None:
        return

    name = Path(project_file["name"])

    if name.exists() and not force:
        print(
            f"Keeping {name}, compare it with {project_file['source']}", file=sys.stderr
        )
    else:
        shutil.copyfile(project_file["source"], name)
        print(f"Wrote {name}", file=sys.stderr)


def parser(checkouts: Collection[str] = ()) -> argparse.ArgumentParser:
    """The parser of the command line, choosing among the checkouts."""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=HelpFormatter, parents=[CONFIG.parser()]
    )
    parser.add_argument(
        "checkouts", nargs="+", choices=checkouts, help="Checkouts to vendor."
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="Overwrite the project files selecting the copies.",
    )

    return parser


@entrypoint
def main() -> None:
    """Parse the arguments and vendor the checkouts."""
    checkouts = CONFIG.parse()
    args = complete(parser(checkouts)).parse_args()

    for name in args.checkouts:
        vendor(checkouts[name], args.force)


if __name__ == "__main__":
    main()
