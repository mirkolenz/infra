"""Interactively bump the pyproject.toml bounds that exclude the latest versions.

Covers every project of the workspace, so run it in the workspace root.

Like npm-check-updates, bounds that already allow the latest version stay untouched,
and the others keep their precision, so `>=2,<3` becomes `>=3,<4` instead of `>=3.1.4,<4`.
"""

import json
import subprocess
import sys
from collections.abc import Iterator, Mapping
from itertools import groupby
from operator import itemgetter
from pathlib import Path
from typing import NotRequired, TypedDict

import questionary
import tomllib
from packaging.requirements import Requirement
from packaging.specifiers import Specifier, SpecifierSet
from packaging.utils import canonicalize_name
from packaging.version import Version

type Section = tuple[str, ...]


class Node(TypedDict):
    """A package of the `uv tree` resolution."""

    name: NotRequired[str]
    latest_version: NotRequired[str]


class Member(TypedDict):
    """A project of the `uv tree` workspace."""

    name: str
    path: str


class Tree(TypedDict):
    """The JSON output of `uv tree`."""

    workspace_root: str
    members: list[Member]
    resolution: dict[str, Node]


def uv(*args: str) -> str:
    """Run uv with the given arguments and return its standard output."""
    return subprocess.run(
        ["uv", *args], check=True, stdout=subprocess.PIPE, text=True
    ).stdout


def outdated_tree() -> Tree:
    """The workspace dependencies with their latest versions, honoring settings such as `exclude-newer`."""
    return json.loads(
        uv(
            "tree",
            "--outdated",
            "--universal",
            "--all-groups",
            "--depth=1",
            "--format=json",
            "--preview-features=json-output",
        )
    )


def latest_versions(tree: Tree) -> dict[str, Version]:
    """Latest versions of the direct dependencies of all workspace projects."""
    return {
        canonicalize_name(node["name"]): Version(node["latest_version"])
        for node in tree["resolution"].values()
        if "name" in node and "latest_version" in node
    }


def projects(tree: Tree) -> Iterator[tuple[str, Section, Path]]:
    """The name, `uv add` arguments, and directory of each workspace project.

    A virtual workspace root is no member, but may still declare dependency groups.
    """
    root = Path(tree["workspace_root"])
    members = {Path(member["path"]): member["name"] for member in tree["members"]}

    if root not in members:
        yield "workspace", (), root

    for path, name in members.items():
        yield name, ("--package", name), path


def sections(path: Path) -> Iterator[tuple[Section, list[str]]]:
    """The `uv add` arguments of each dependency section with its requirements."""
    pyproject = tomllib.loads((path / "pyproject.toml").read_text())
    project = pyproject.get("project", {})
    yield (), project.get("dependencies", [])

    for extra, deps in project.get("optional-dependencies", {}).items():
        yield ("--optional", extra), deps

    for group, deps in pyproject.get("dependency-groups", {}).items():
        yield ("--group", group), [dep for dep in deps if isinstance(dep, str)]


def truncate(version: Version, precision: int, increment: bool = False) -> str:
    """The release of `version` with `precision` components, optionally incrementing the last.

    >>> truncate(Version("3.1.4"), 1)
    '3'
    >>> truncate(Version("3.1.4"), 2, increment=True)
    '3.2'
    >>> truncate(Version("3"), 3)
    '3.0.0'
    """
    release = [*version.release, *[0] * precision][:precision]
    release[-1] += increment

    return ".".join(map(str, release))


def bump(spec: Specifier, latest: Version) -> str:
    """The specifier moved to `latest` at its current precision.

    >>> bump(Specifier(">=0.12"), Version("0.14.1"))
    '>=0.14'
    >>> bump(Specifier("<0.13"), Version("0.14.1"))
    '<0.15'
    >>> bump(Specifier("~=1.2"), Version("2.5.0"))
    '~=2.5'
    >>> bump(Specifier("!=1.3"), Version("2.5.0"))
    '!=1.3'
    """
    match spec.operator:
        case ">=" | "~=" | "<":
            precision = len(Version(spec.version).release)
            increment = spec.operator == "<"

            return spec.operator + truncate(latest, precision, increment)

        case _:
            return str(spec)


def upgrade(requirement: str, latest: Mapping[str, Version]) -> str | None:
    """The requirement with bumped bounds if they exclude the latest version.

    >>> upgrade("foo[b,a] >= 2, < 3 ; python_version < '3.14'", {"foo": Version("3.1.4")})
    'foo[a,b]>=3,<4; python_version < "3.14"'
    >>> upgrade("foo>=2,<4", {"foo": Version("3.1.4")})
    >>> upgrade("foo==2.0.0", {"foo": Version("3.1.4")})
    """
    req = Requirement(requirement)
    version = latest.get(canonicalize_name(req.name))

    if version is None or req.specifier.contains(version, prereleases=True):
        return None

    specs = ",".join(bump(spec, version) for spec in req.specifier)

    if not SpecifierSet(specs).contains(version, prereleases=True):
        return None

    extras = f"[{','.join(sorted(req.extras))}]" if req.extras else ""
    marker = f"; {req.marker}" if req.marker else ""

    return f"{req.name}{extras}{specs}{marker}"


def main() -> None:
    """Prompt for the bumps and apply the selected ones with `uv add`."""
    tree = outdated_tree()
    latest = latest_versions(tree)
    choices = [
        questionary.Choice(
            f"{name}: {old}  →  {new}", value=((*target, *section), new), checked=True
        )
        for name, target, path in projects(tree)
        for section, deps in sections(path)
        for old in deps
        if (new := upgrade(old, latest))
    ]

    if not choices:
        print("All dependency bounds allow the latest versions.")
        return

    selected: list[tuple[Section, str]] | None = questionary.checkbox(
        "Choose which bounds to bump:", choices=choices
    ).ask()

    if selected is None:
        sys.exit(1)

    for section, bumps in groupby(selected, key=itemgetter(0)):
        uv("add", "--frozen", *section, *(new for _, new in bumps))


if __name__ == "__main__":
    main()
