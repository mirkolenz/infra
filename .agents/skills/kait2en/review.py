#!/usr/bin/env python3
"""Review helper for the kait2en skill, run from anywhere in the repository."""

import argparse
import json
import os
import subprocess
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any, TypedDict

CHECK = Path("pkgs/by-name/kait2en/upstream-check.nix")
FORK = "LukeChannings/KaiT2en-NixOS"
# Only the fork's Nix layer, the rest mirrors upstream.
FORK_PREFIXES = ("nix/", "patches/nixos/", ".agents/")
PINS_EXPR = """c: {
  upstream = "${c.src.owner}/${c.src.repo}";
  reviewed_fork = c.reviewedFork;
  reviewed_rev = c.reviewedSrc.rev;
  reviewed_hash = c.reviewedSrc.outputHash;
  rev = c.src.rev;
  hash = c.src.outputHash;
}"""


@dataclass(frozen=True, slots=True)
class Pins:
    """Pinned revisions of `upstream-check.nix` and the upstream they track."""

    upstream: str
    reviewed_fork: str
    reviewed_rev: str
    reviewed_hash: str
    rev: str
    hash: str


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


def load_pins() -> Pins:
    """Evaluates every pin at once so a failure aborts before any request."""
    return Pins(
        **run_json(
            "nix",
            "eval",
            "--json",
            ".#packages.x86_64-linux.kait2en-upstream-check",
            "--apply",
            PINS_EXPR,
        )
    )


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


def replace_once(path: Path, replacements: Mapping[str, str]) -> None:
    """Replaces each quoted old value in a file with the new one, requiring exactly one match."""
    text = path.read_text()

    for old, new in replacements.items():
        if (count := text.count(f'"{old}"')) != 1:
            raise SystemExit(f'{path}: expected "{old}" once, found {count}')

        text = text.replace(f'"{old}"', f'"{new}"')

    path.write_text(text)


def main() -> None:
    """Parses the arguments and runs the subcommand."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser(
        "upstream",
        help="commits and files upstream changed from `reviewedSrc` to `src`",
    )
    commands.add_parser(
        "fork",
        help="commits and Nix layer files the NixOS fork changed since `reviewedFork`",
    )
    commands.add_parser(
        "advance",
        help="moves `reviewedSrc` to `src` and `reviewedFork` to the fork's main",
    )
    args = parser.parse_args()

    os.chdir(run("git", "rev-parse", "--show-toplevel").strip())
    pins = load_pins()

    match args.command:
        case "upstream":
            compare(pins.upstream, pins.reviewed_rev, pins.rev, lambda _: True)

        case "fork":
            compare(FORK, pins.reviewed_fork, "main", is_fork_nix)

        case "advance":
            fork_head: Commit = run_json("gh", "api", f"repos/{FORK}/commits/main")
            replace_once(
                CHECK,
                {
                    pins.reviewed_rev: pins.rev,
                    pins.reviewed_hash: pins.hash,
                    pins.reviewed_fork: fork_head["sha"],
                },
            )
            subprocess.run(("git", "diff", "--stat", "--", CHECK), check=True)


if __name__ == "__main__":
    main()
