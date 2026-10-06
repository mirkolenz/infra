"""Interactively bump the pyproject.toml bounds that exclude the latest versions.

Like npm-check-updates, bounds that already allow the latest version stay untouched,
and the others keep their precision, so `>=2,<3` becomes `>=3,<4` instead of `>=3.1.4,<4`.
"""

import json
import subprocess
import sys
import tomllib
from collections.abc import Iterator, Mapping
from itertools import groupby
from operator import itemgetter
from pathlib import Path

import questionary
from packaging.requirements import Requirement
from packaging.specifiers import Specifier, SpecifierSet
from packaging.utils import canonicalize_name
from packaging.version import Version

type Section = tuple[str, ...]


def uv(*args: str) -> str:
    """Run uv with the given arguments and return its standard output."""
    return subprocess.run(
        ["uv", *args], check=True, stdout=subprocess.PIPE, text=True
    ).stdout


def latest_versions() -> dict[str, Version]:
    """Latest versions of the direct dependencies, honoring uv settings such as `exclude-newer`."""
    tree = json.loads(
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

    return {
        canonicalize_name(node["name"]): Version(node["latest_version"])
        for node in tree["resolution"].values()
        if "latest_version" in node
    }


def sections() -> Iterator[tuple[Section, list[str]]]:
    """The `uv add` arguments of each dependency section with its requirements."""
    pyproject = tomllib.loads(Path("pyproject.toml").read_text())
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
    latest = latest_versions()
    choices = [
        questionary.Choice(f"{old}  →  {new}", value=(section, new), checked=True)
        for section, deps in sections()
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
