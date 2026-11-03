#!/usr/bin/env python3
"""Review helper for the kait2en skill, run from anywhere in the repository."""

import argparse
import json
import os
import subprocess
from collections.abc import Callable
from pathlib import Path
from typing import Any, TypedDict

REVIEWED = Path("pkgs/by-name/kait2en/reviewed.json")
OUTDATED_ATTR = ".#packages.x86_64-linux.kait2en-upstream-check.outdated"
UPSTREAM = "kaiT2en/KaiT2en-Fedora"
FORK = "LukeChannings/KaiT2en-NixOS"
# Only the fork's Nix layer, the rest mirrors upstream.
FORK_PREFIXES = ("nix/", "patches/nixos/", ".agents/")


class ForkPin(TypedDict):
    """Revision of the NixOS fork."""

    rev: str


class UpstreamPin(ForkPin):
    """Revision of upstream and the hash of its tree."""

    hash: str


class Reviewed(TypedDict):
    """Contents of `reviewed.json`, the revisions last reviewed."""

    upstream: UpstreamPin
    fork: ForkPin


class CommitDetail(TypedDict):
    """Git data of a commit in the GitHub API."""

    message: str


class Commit(TypedDict):
    """Commit in the GitHub API."""

    sha: str
    commit: CommitDetail


class File(TypedDict):
    """Changed file in the GitHub API."""

    filename: str
    status: str


class Comparison(TypedDict):
    """Response of the GitHub compare API."""

    commits: list[Commit]
    files: list[File]


def run(*args: str) -> str:
    """Runs a command and returns its stdout, aborting on failure."""
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, text=True).stdout


def run_json(*args: str) -> Any:
    """Runs a command and returns its stdout parsed as JSON, aborting on failure."""
    return json.loads(run(*args))


def load_reviewed() -> Reviewed:
    """Reads the revisions last reviewed."""
    return json.loads(REVIEWED.read_text())


def compare(repo: str, base: str, head: str, keep: Callable[[str], bool]) -> None:
    """Prints the commits of a range and its files accepted by `keep`."""
    comparison: Comparison = run_json(
        "gh", "api", f"repos/{repo}/compare/{base}...{head}"
    )

    for commit in comparison["commits"]:
        print(commit["sha"][:8], commit["commit"]["message"].split("\n")[0])

    print()

    for file in comparison["files"]:
        if keep(file["filename"]):
            print(f"{file['status']}\t{file['filename']}")


def is_fork_nix(filename: str) -> bool:
    """Tells whether a file of the fork belongs to its Nix layer.

    >>> [is_fork_nix(f) for f in ("nix/a.nix", "flake.nix", "x/package.nix", "src/flake.nix")]
    [True, True, True, False]
    """
    return (
        filename.startswith(FORK_PREFIXES)
        or filename == "flake.nix"
        or filename.endswith("package.nix")
    )


def main() -> None:
    """Parses the arguments and runs the subcommand."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser(
        "upstream",
        help="commits and files upstream changed since its reviewed revision",
    )
    commands.add_parser(
        "fork",
        help="commits and Nix layer files the NixOS fork changed since its reviewed revision",
    )
    commands.add_parser(
        "advance",
        help="moves both reviewed revisions to the main branches",
    )
    commands.add_parser(
        "update",
        help="runs nix-update for the packages whose files differ from the reviewed revision",
    )
    args = parser.parse_args()

    os.chdir(run("git", "rev-parse", "--show-toplevel").strip())
    reviewed = load_reviewed()

    match args.command:
        case "upstream":
            compare(UPSTREAM, reviewed["upstream"]["rev"], "main", lambda _: True)

        case "fork":
            compare(FORK, reviewed["fork"]["rev"], "main", is_fork_nix)

        case "advance":
            # Locks the default branch, so revision and hash match.
            upstream = run_json(
                "nix", "flake", "prefetch", "--json", f"github:{UPSTREAM}"
            )
            fork_head: Commit = run_json("gh", "api", f"repos/{FORK}/commits/main")
            reviewed = {
                "upstream": {
                    "rev": upstream["locked"]["rev"],
                    "hash": upstream["hash"],
                },
                "fork": {"rev": fork_head["sha"]},
            }
            REVIEWED.write_text(json.dumps(reviewed, indent=2) + "\n")
            subprocess.run(("git", "diff", "--", REVIEWED), check=True)

        case "update":
            outdated = run(
                "nix",
                "build",
                "--no-link",
                "--print-out-paths",
                OUTDATED_ATTR,
            )

            for name in Path(outdated.strip()).read_text().split():
                subprocess.run(
                    (
                        "nix-update",
                        f"kait2en.{name}",
                        "--system",
                        "x86_64-linux",
                        "--version=branch",
                    ),
                    check=True,
                )


if __name__ == "__main__":
    main()
