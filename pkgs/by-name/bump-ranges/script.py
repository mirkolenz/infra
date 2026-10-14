"""Interactively bump the dependency ranges that exclude the latest versions.

Covers every project of the workspace, so run it in the workspace root.

Ranges that already allow the latest version stay untouched, the others keep their precision.
So `>=2,<3` becomes `>=3,<4` instead of `>=3.1.4,<4`, like with npm-check-updates.
The package managers resolve the latest versions and edit the manifests, honoring their minimum release ages.
"""

import json
import subprocess
import sys
import tomllib
from collections.abc import Callable, Container, Iterable, Iterator, Mapping, Sequence
from dataclasses import dataclass
from functools import cache
from itertools import groupby, takewhile
from operator import attrgetter
from pathlib import Path
from typing import Any

import questionary
import typer
from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet
from packaging.utils import canonicalize_name
from packaging.version import InvalidVersion, Version

type Args = tuple[str, ...]

OPERATORS = "^~=<>!"
# operators whose version moves to the latest one, with `<` moving one past it
BUMPED = {"", "=", "==", "^", "~", "~=", ">=", "<"}
WILDCARDS = {"x", "X", "*"}
NODE_SECTIONS = ("dependencies", "devDependencies", "optionalDependencies")
PHP_SECTIONS: dict[str, Args] = {"require": (), "require-dev": ("--dev",)}
STYLE = questionary.Style(
    [
        ("separator", "fg:ansiblue bold"),
        ("old", "fg:ansired"),
        ("arrow", "fg:ansibrightblack"),
        ("new", "fg:ansigreen bold"),
    ]
)

app = typer.Typer(help=__doc__, no_args_is_help=True, add_completion=False)


@dataclass(frozen=True, slots=True)
class Bump:
    """A dependency range to move, with the command applying it and its argument."""

    project: str
    section: str
    name: str
    old: str
    new: str
    command: Args
    arg: str


@dataclass(frozen=True, slots=True)
class Section:
    """A dependency section of a pyproject with the `uv add` arguments selecting it."""

    name: str
    args: Args
    requirements: Sequence[str]


@dataclass(frozen=True, slots=True)
class Outdated:
    """A dependency of a JSON manifest with a latest version outside its range."""

    name: str
    latest: str
    location: str = ""


type Edit = Callable[[Outdated, str, str], tuple[Args, str]]


def run(*args: str, codes: Container[int] = (0,)) -> str:
    """Run a command and return its standard output, exiting with its code on failure."""
    process = subprocess.run(args, check=False, stdout=subprocess.PIPE, text=True)

    if process.returncode not in codes:
        raise typer.Exit(process.returncode)

    return process.stdout


def bump_range(comparator: str, latest: str) -> str:
    """The comparator moved to `latest` at its precision, unchanged unless it is a plain one.

    >>> bump_range(">=0.12", "0.14.1")
    '>=0.14'
    >>> bump_range("<0.13", "0.14.1")
    '<0.15'
    >>> bump_range("~2.0", "v3.12.1")
    '~3.12'
    >>> bump_range("1.0.*", "3.1.4")
    '3.1.*'
    >>> bump_range("!=1.3", "2.5.0")
    '!=1.3'
    >>> bump_range("^1 || ^2", "3.1.4")
    '^1 || ^2'
    """
    version = comparator.lstrip(OPERATORS)
    operator = comparator.removesuffix(version)
    parts = version.split(".")
    precision = len(list(takewhile(str.isdigit, parts)))
    wildcards = parts[precision:]

    if operator not in BUMPED or not precision or not WILDCARDS.issuperset(wildcards):
        return comparator

    try:
        release = [*Version(latest).release, *[0] * precision][:precision]
    except InvalidVersion:
        return comparator

    release[-1] += operator == "<"

    return operator + ".".join([*map(str, release), *wildcards])


def uv_bumps() -> Iterator[Bump]:
    """The bumps of a uv workspace."""
    match json.loads(
        run(
            "uv",
            "tree",
            "--outdated",
            "--universal",
            "--all-groups",
            "--depth=1",
            "--format=json",
            "--preview-features=json-output",
        )
    ):
        case {
            "workspace_root": str(root),
            "members": list(members),
            "resolution": dict(resolution),
        }:
            # a virtual workspace root is no member, but may still declare dependency groups
            projects: dict[Path, tuple[str, Args]] = {Path(root): ("workspace", ())} | {
                Path(member["path"]): (member["name"], ("--package", member["name"]))
                for member in members
            }
            latest: dict[str, str] = {
                canonicalize_name(node["name"]): node["latest_version"]
                for node in resolution.values()
                if "latest_version" in node
            }
        case output:
            sys.exit(f"Unexpected output of `uv tree`: {output}")

    yield from filter(
        None,
        (
            requirement_bump(project, target, section, dep, latest)
            for path, (project, target) in projects.items()
            for section in pyproject_sections(path)
            for dep in section.requirements
        ),
    )


def pyproject_sections(path: Path) -> Iterator[Section]:
    """The dependency sections of a pyproject."""
    pyproject = tomllib.loads((path / "pyproject.toml").read_text())
    project = pyproject.get("project", {})
    yield Section("dependencies", (), project.get("dependencies", []))

    for extra, deps in project.get("optional-dependencies", {}).items():
        yield Section(f"optional {extra}", ("--optional", extra), deps)

    for group, deps in pyproject.get("dependency-groups", {}).items():
        yield Section(
            f"group {group}",
            ("--group", group),
            [dep for dep in deps if isinstance(dep, str)],
        )


def requirement_bump(
    project: str, target: Args, section: Section, dep: str, latest: Mapping[str, str]
) -> Bump | None:
    """The bump of a requirement, if it excludes the latest version."""
    req = Requirement(dep)
    version = latest.get(canonicalize_name(req.name))

    if version is None or req.specifier.contains(version, prereleases=True):
        return None

    specs = [str(spec) for spec in req.specifier]
    new = ",".join(bump_range(spec, version) for spec in specs)

    if not SpecifierSet(new).contains(version, prereleases=True):
        return None

    # built by hand to keep the order of the specifiers, which `str(req)` sorts
    extras = f"[{','.join(sorted(req.extras))}]" if req.extras else ""
    marker = f"; {req.marker}" if req.marker else ""
    command = ("uv", "add", "--frozen", *target, *section.args)

    return Bump(
        project,
        section.name,
        req.name,
        ",".join(specs),
        new,
        command,
        f"{req.name}{extras}{new}{marker}",
    )


@cache
def load_json(path: Path) -> dict[str, Any]:
    """The parsed JSON manifest, read once."""
    return json.loads(path.read_text())


def manifest_bumps(
    outdated: Iterable[Outdated], filename: str, sections: Iterable[str], edit: Edit
) -> Iterator[Bump]:
    """The bumps of JSON manifests, given the sections and the edit setting a range."""
    for package in outdated:
        manifest = load_json(Path(package.location, filename))
        project = manifest.get("name", package.location or filename)

        for section in sections:
            old = manifest.get(section, {}).get(package.name)

            if old is not None and (new := bump_range(old, package.latest)) != old:
                yield Bump(
                    project,
                    section,
                    package.name,
                    old,
                    new,
                    *edit(package, section, new),
                )


def npm_outdated() -> Iterator[Outdated]:
    """The dependencies whose latest versions npm resolves outside their ranges."""
    # npm exits with 1 if anything is outdated
    match json.loads(run("npm", "outdated", "--json", "--long", codes=(0, 1))):
        case {"error": {"summary": str(summary)}}:
            sys.exit(summary)
        case dict(packages):
            # npm lists a dependency of several workspaces once per workspace
            entries = [
                (name, entry)
                for name, value in packages.items()
                for entry in (value if isinstance(value, list) else [value])
            ]
        case output:
            sys.exit(f"Unexpected output of `npm outdated`: {output}")

    for name, entry in entries:
        match entry:
            case {
                "wanted": str(wanted),
                "latest": str(latest),
                "dependedByLocation": str(location),
            } if wanted != latest:
                # npm calls the root `global` if its manifest has no name
                yield Outdated(name, latest, "" if location == "global" else location)


def npm_edit(package: Outdated, section: str, new: str) -> tuple[Args, str]:
    """The command setting ranges of a package.json and its argument, whose key may contain dots."""
    workspace = ("--workspace", package.location) if package.location else ()

    return ("npm", "pkg", "set", *workspace), f"{section}[{package.name}]={new}"


def composer_outdated() -> Iterator[Outdated]:
    """The dependencies whose latest versions composer resolves beyond their major versions."""
    # composer prints an empty list instead of an object without locked packages
    match json.loads(
        run("composer", "outdated", "--direct", "--locked", "--format=json")
    ):
        case {"locked": list(packages)}:
            for package in packages:
                match package:
                    case {
                        "name": str(name),
                        "latest": str(latest),
                        "latest-status": "update-possible",
                    }:
                        yield Outdated(name, latest)


def composer_edit(package: Outdated, section: str, new: str) -> tuple[Args, str]:
    """The command setting ranges of a composer.json and its argument."""
    command = ("composer", "require", "--no-update", *PHP_SECTIONS[section])

    return command, f"{package.name}:{new}"


def select(bumps: Sequence[Bump]) -> list[Bump] | None:
    """Prompt for the bumps to apply, grouped by project and section."""
    name_width = max(len(bump.name) for bump in bumps)
    old_width = max(len(bump.old) for bump in bumps)
    choices: list[questionary.Choice | questionary.Separator] = []

    for (project, section), group in groupby(
        bumps, key=attrgetter("project", "section")
    ):
        choices.append(questionary.Separator(f"── {project} · {section}"))
        choices.extend(
            questionary.Choice(
                [
                    ("", f"{bump.name:<{name_width}}  "),
                    ("class:old", f"{bump.old:>{old_width}}"),
                    ("class:arrow", "  →  "),
                    ("class:new", bump.new),
                ],
                value=bump,
                checked=True,
            )
            for bump in group
        )

    return questionary.checkbox("Select the ranges to bump", choices, style=STYLE).ask()


def apply(bumps: Iterable[Bump]) -> None:
    """Prompt for the bumps and apply the selected ones, with one command per target."""
    if not (bumps := list(bumps)):
        typer.echo("All dependency ranges allow the latest versions.")
        return

    if (selected := select(bumps)) is None:
        raise typer.Exit(1)

    commands: dict[Args, list[str]] = {}

    for bump in selected:
        commands.setdefault(bump.command, []).append(bump.arg)

    for command, args in commands.items():
        run(*command, *args)


@app.command()
def python() -> None:
    """Bump the ranges of a uv workspace, honoring settings such as `exclude-newer`."""
    apply(uv_bumps())


@app.command()
def node() -> None:
    """Bump the ranges of an npm or bun workspace with installed packages, honoring `min-release-age` of npm."""
    apply(manifest_bumps(npm_outdated(), "package.json", NODE_SECTIONS, npm_edit))


@app.command()
def php() -> None:
    """Bump the ranges of a composer project."""
    apply(
        manifest_bumps(
            composer_outdated(), "composer.json", PHP_SECTIONS, composer_edit
        )
    )


if __name__ == "__main__":
    app()
