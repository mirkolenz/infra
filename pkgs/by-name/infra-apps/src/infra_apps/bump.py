"""Update and commit the dependencies of projects, or bump their dependency ranges.

`bump update [MANAGER ...]`, or plain `bump` for all managers, updates the projects at or below
the working directory and commits them per project and package manager.
The managers `nix` and `actions` of flakes and GitHub Actions are built in,
and the config of `--config` adds others or replaces them.
`bump ranges ECOSYSTEM` interactively bumps the dependency ranges of a workspace
that exclude the latest versions, which `update` also does ahead of the commands of a manager.
Both take the options of the range bumps after their command name,
and with `--dry-run`, `update` only lists the range bumps of each project.

The config is a JSON object mapping the name of each package manager,
which is its scope in the commit messages, to an object of
- `lockfile`, the path of the lockfile relative to the root of a project, which marks its projects,
- `excludes`, glob patterns of the lockfiles that belong to no project of their own,
- `pathspecs`, git pathspecs of the other files it changes besides those of its range bumps,
  which may match no file,
- `ranges`, the ecosystem whose ranges to bump first,
- `commands`, objects of the `args` to run, where `{message}` stands for the commit message,
  and an `ifExists` path that has to exist for the command to run,
- `env`, the environment variables of the commands,
of which all but `lockfile` are optional.
"""

import argparse
import json
import os
import sys
import tomllib
from collections.abc import (
    Callable,
    Collection,
    Iterable,
    Iterator,
    Mapping,
    Sequence,
)
from concurrent.futures import ThreadPoolExecutor
from contextlib import chdir
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from functools import cache
from itertools import groupby, takewhile
from operator import attrgetter
from pathlib import Path
from typing import Any

import yaml
from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet
from packaging.utils import canonicalize_name
from packaging.version import InvalidVersion, Version

from infra_apps.apptools import (
    CommandError,
    ConfigOption,
    Error,
    HelpFormatter,
    add_command,
    complete,
    entrypoint,
    run,
    run_json,
    run_nul,
)

type Args = tuple[str, ...]

RANGES_DOC = """Interactively bump the dependency ranges that exclude the latest versions.

Covers every project of the workspace, so run it in the workspace root.

Ranges that already allow the latest version stay untouched, the others keep their precision.
So `>=2,<3` becomes `>=3,<4` instead of `>=3.1.4,<4`, like with npm-check-updates.
The package managers resolve the latest versions and edit the manifests, honoring their minimum release ages,
while the tags of GitHub Actions and flake inputs follow the releases older than `--min-age`
whose commits reached a branch at least as long ago, which also gates relocking an `actions.lock`.
"""
OPERATORS = "^~=<>!"
# operators whose version moves to the latest one, with `<` moving one past it
BUMPED = {"", "=", "==", "^", "~", "~=", ">=", "<"}
# operators of exact versions, which a shorter version would change instead of widen
EXACT = {"", "=", "=="}
WILDCARDS = {"x", "X", "*"}
NODE_SECTIONS = ("dependencies", "devDependencies", "optionalDependencies")
PHP_SECTIONS: dict[str, Args] = {"require": (), "require-dev": ("--dev",)}
# replaced by the new ref in the template of a tagged ref, and spelled out in FLAKE_INPUTS
PLACEHOLDER = "__ref__"
# replaced by the commit message in the arguments of the commands of a package manager
MESSAGE = "{message}"
# the inputs of a flake with a ref, their url, the url with the placeholder as ref, and the position of the url
FLAKE_INPUTS = """
flake:
builtins.mapAttrs (
  name: input:
  let
    ref = builtins.parseFlakeRef input.url;
  in
  if input ? url && ref ? ref then
    {
      inherit (input) url;
      inherit ref;
      template = builtins.flakeRefToString (ref // { ref = "__ref__"; });
      pos = builtins.unsafeGetAttrPos "url" input;
    }
  else
    null
) flake.inputs
"""
# the files of the workflows and composite actions, as pathspecs
ACTION_PATHSPECS = (
    ":(glob).github/workflows/*.y*ml",
    ":(glob).github/actions/**/action.y*ml",
    ":(glob)action.y*ml",
)
ACTIONS_LOCK = Path(".github/workflows/actions.lock")
# like renovate, neither narrow refs such as `v4` to `v4.2.1` nor migrate local actions
LOCK_FLAGS = ("--no-interactive", "--no-narrow", "--no-migrate-local-actions")
# the `before` of a new branch and the `after` of a deleted one
NULL_COMMIT = "0" * 40
# the time periods of the activity log by their days
PERIODS = {"day": 1, "week": 7, "month": 30, "quarter": 90, "year": 365}
# the classes of the prompt and their styles
STYLE = [
    ("separator", "fg:ansiblue bold"),
    ("old", "fg:ansibrightblack"),
    ("arrow", "fg:ansibrightblack"),
    ("major", "fg:ansired bold"),
    ("minor", "fg:ansiyellow bold"),
    ("patch", "fg:ansigreen bold"),
]


class Level(StrEnum):
    """The level of a version change, from the most to the least severe."""

    MAJOR = "major"
    MINOR = "minor"
    PATCH = "patch"

    @property
    def rank(self) -> int:
        """The position from the most to the least severe level."""
        return list(Level).index(self)


@dataclass(frozen=True, slots=True)
class Precision:
    """The components of a version to keep up to a level, counted after leading zeros unless they are minor ones."""

    level: Level
    zero_major: bool = True

    def length(self, numbers: Sequence[int]) -> int:
        """The number of components to keep of a version.

        >>> Precision(Level.MAJOR).length([0, 29, 1])
        2
        >>> Precision(Level.MAJOR, zero_major=False).length([0, 29, 1])
        1
        """
        zeros = leading_zeros(numbers) if self.zero_major else 0

        return min(zeros, len(numbers) - 1) + self.level.rank + 1


@dataclass(frozen=True, slots=True)
class Replace:
    """A replacement of a text within a line of a file."""

    path: Path
    line: int
    old: str

    def __call__(self, new: str) -> None:
        """Replace the text with the new one, failing if the file changed in the meantime."""
        lines = self.path.read_text().splitlines(keepends=True)

        if self.old not in lines[self.line]:
            raise Error(f"{self.path}:{self.line + 1} no longer holds {self.old}")

        lines[self.line] = lines[self.line].replace(self.old, new, 1)
        self.path.write_text("".join(lines))


@dataclass(frozen=True, slots=True)
class Bump:
    """A dependency range to move, by its comparators, with the command or replacement applying it and its argument.

    The selected bumps sharing a command apply together.
    """

    project: str
    section: str
    name: str
    old: tuple[str, ...]
    new: tuple[str, ...]
    edit: Args | Replace
    arg: str

    def level(self, zero_major: bool) -> Level:
        """The most severe change among the comparators of the range."""
        changes = (
            change(old, new, zero_major)
            for old, new in zip(self.old, self.new, strict=True)
            if old != new
        )

        return min(changes, key=attrgetter("rank"), default=Level.MAJOR)

    @property
    def qualified(self) -> bool:
        """Whether every comparator of the range names a full version, such as `1.2.3`."""
        return all(len(parse(old)[1]) >= 3 for old in self.old)


@dataclass(frozen=True, slots=True)
class Mode:
    """Which bumps to offer, at which precision, up to which level to accept them without prompting, or whether to only list them.

    The tags of GitHub Actions and flake inputs follow the releases older than `min_age` days.
    """

    accept: Level | None
    qualified: bool
    precision: Precision
    dry_run: bool
    min_age: int

    def apply(self, bumps: Iterable[Bump]) -> None:
        """Apply the bumps of the mode, running each command once."""
        bumps = [bump for bump in bumps if bump.qualified or not self.qualified]

        if self.accept is not None:
            rank = self.accept.rank
            bumps = [
                bump
                for bump in bumps
                if bump.level(self.precision.zero_major).rank >= rank
            ]

        if not bumps:
            print("No dependency ranges to bump.")
            return

        if self.dry_run:
            for bump in bumps:
                old, new = ",".join(bump.old), ",".join(bump.new)
                level = bump.level(self.precision.zero_major)
                print(
                    f"{bump.project} · {bump.section}: {bump.name} {old} → {new} ({level})"
                )

            return

        if (
            selected := bumps if self.accept is not None else self.select(bumps)
        ) is None:
            raise SystemExit(1)

        commands: dict[Args, list[str]] = {}

        for bump in selected:
            match bump.edit:
                case Replace() as replace:
                    replace(bump.arg)
                case command:
                    commands.setdefault(command, []).append(bump.arg)

        for command, args in commands.items():
            run(*command, *args)

    def select(self, bumps: Sequence[Bump]) -> list[Bump] | None:
        """Prompt for the bumps to apply, grouped by project and section, with their new versions colored by level."""
        name_width = max(len(bump.name) for bump in bumps)
        old_width = max(len(",".join(bump.old)) for bump in bumps)
        # imported here, since it takes most of the startup of the other commands and the completions
        import questionary

        choices: list[questionary.Choice | questionary.Separator] = []

        for (project, section), group in groupby(
            bumps, key=attrgetter("project", "section")
        ):
            choices.append(questionary.Separator(f"── {project} · {section}"))
            choices.extend(
                questionary.Choice(
                    [
                        ("", f"{bump.name:<{name_width}}  "),
                        ("class:old", f"{','.join(bump.old):>{old_width}}"),
                        ("class:arrow", "  →  "),
                        (
                            f"class:{bump.level(self.precision.zero_major)}",
                            ",".join(bump.new),
                        ),
                    ],
                    value=bump,
                    checked=True,
                )
                for bump in group
            )

        return questionary.checkbox(
            "Select the ranges to bump", choices, style=questionary.Style(STYLE)
        ).ask()


@dataclass(frozen=True, slots=True)
class Tagged:
    """A ref of a GitHub repository within a line of a file, with the template of the text holding it."""

    project: str
    section: str
    name: str
    repo: str
    ref: str
    edit: Replace
    template: str


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


def ls_files(*pathspecs: str) -> list[str]:
    """The tracked and untracked files at or below the working directory that the pathspecs match."""
    return run_nul(
        "git",
        "ls-files",
        "-z",
        "--cached",
        "--others",
        "--exclude-standard",
        "--",
        *pathspecs,
    )


def parse(comparator: str) -> tuple[str, list[int], list[str]]:
    """The operator with an optional `v` prefix, the leading numeric components, and the other components of a comparator or tag.

    >>> parse("^v0.12.x")
    ('^v', [0, 12], ['x'])
    """
    version = comparator.lstrip(OPERATORS).removeprefix("v")
    parts = version.split(".")
    numbers = list(takewhile(str.isdigit, parts))

    return comparator.removesuffix(version), [*map(int, numbers)], parts[len(numbers) :]


def bump_range(comparator: str, latest: str, precision: Precision | None = None) -> str:
    """The comparator moved to `latest` at its precision, unchanged unless it is a plain one.

    A precision shortens the moved version of a range, as long as its lower bound
    allows no older version than before, so exact versions and `~=` keep their length.

    >>> bump_range(">=0.12", "0.14.1")
    '>=0.14'
    >>> bump_range("<0.13", "0.14.1")
    '<0.15'
    >>> bump_range("~2.0", "v3.12.1")
    '~3.12'
    >>> bump_range("1.0.*", "3.1.4")
    '3.1.*'
    >>> bump_range("v4", "v5.0.1")
    'v5'
    >>> bump_range("!=1.3", "2.5.0")
    '!=1.3'
    >>> bump_range("^1 || ^2", "3.1.4")
    '^1 || ^2'
    >>> major = Precision(Level.MAJOR)
    >>> bump_range("^3.2.1", "4.5.0", major)
    '^4'
    >>> bump_range(">=4.1", "4.5.0", major)
    '>=4.5'
    >>> bump_range("<3.2.1", "4.5.0", major)
    '<5'
    >>> bump_range("<0.2", "0.3.0", major)
    '<0.4'
    >>> bump_range("~=1.2.3", "2.5.0", major)
    '~=2.5'
    >>> bump_range("==1.2.3", "2.5.0", major)
    '==2.5.0'
    """
    head, numbers, rest = parse(comparator)
    operator = head.removesuffix("v")

    if operator not in BUMPED or not numbers or not WILDCARDS.issuperset(rest):
        return comparator

    try:
        release = [*Version(latest).release, *[0] * len(numbers)][: len(numbers)]
    except InvalidVersion:
        return comparator

    if precision is not None and (operator not in EXACT or rest):
        length = max(precision.length(release), 2 if operator == "~=" else 1)
        shortened = release[:length]

        # zeros pad the shorter version to compare it with the old lower bound
        if (
            operator == "<"
            or [*shortened, *[0] * len(numbers)][: len(numbers)] >= numbers
        ):
            release = shortened

    release[-1] += operator == "<"

    return head + ".".join([*map(str, release), *rest])


def leading_zeros(numbers: Sequence[int]) -> int:
    """The number of leading zeros of the components of a version."""
    return len(list(takewhile(lambda part: part == 0, numbers)))


def change(old: str, new: str, zero_major: bool = True) -> Level:
    """The level of the first component in which the releases of two comparators differ.

    Like caret ranges, it counts from the first component that is not zero unless told otherwise,
    so a change before 1.0 is a major one.

    >>> change("^1.2", "^2.0")
    <Level.MAJOR: 'major'>
    >>> change("v1.10.0", "v1.13.0")
    <Level.MINOR: 'minor'>
    >>> change("v4", "v4.3.1")
    <Level.MINOR: 'minor'>
    >>> change("<0.13", "<0.15")
    <Level.MAJOR: 'major'>
    >>> change("0.29.1", "0.30.0", zero_major=False)
    <Level.MINOR: 'minor'>
    >>> change(">=1.2.3", ">=1.2.5")
    <Level.PATCH: 'patch'>
    """
    old_release, new_release = parse(old)[1], parse(new)[1]
    zeros = leading_zeros(old_release) if zero_major else 0
    diff = next(
        (i for i, (a, b) in enumerate(zip(old_release, new_release)) if a != b),
        len(old_release),
    )
    levels = list(Level)

    return levels[min(max(diff - zeros, 0), len(levels) - 1)]


def uv_bumps(precision: Precision) -> Iterator[Bump]:
    """The bumps of a uv workspace."""
    match run_json(
        "uv",
        "tree",
        "--outdated",
        "--universal",
        "--all-groups",
        "--depth=1",
        "--format=json",
        "--preview-features=json-output",
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
            raise Error(f"Unexpected output of `uv tree`: {output}")

    yield from filter(
        None,
        (
            requirement_bump(project, target, section, dep, latest, precision)
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
    project: str,
    target: Args,
    section: Section,
    dep: str,
    latest: Mapping[str, str],
    precision: Precision,
) -> Bump | None:
    """The bump of a requirement, if it excludes the latest version."""
    req = Requirement(dep)
    version = latest.get(canonicalize_name(req.name))

    if version is None or req.specifier.contains(version, prereleases=True):
        return None

    specs = tuple(str(spec) for spec in req.specifier)
    new = tuple(bump_range(spec, version, precision) for spec in specs)

    if not SpecifierSet(",".join(new)).contains(version, prereleases=True):
        return None

    # built by hand to keep the order of the specifiers, which `str(req)` sorts
    extras = f"[{','.join(sorted(req.extras))}]" if req.extras else ""
    marker = f"; {req.marker}" if req.marker else ""
    command = ("uv", "add", "--frozen", *target, *section.args)

    return Bump(
        project,
        section.name,
        req.name,
        specs,
        new,
        command,
        f"{req.name}{extras}{','.join(new)}{marker}",
    )


def load_json(path: Path) -> dict[str, Any]:
    """The parsed JSON manifest."""
    return json.loads(path.read_text())


def manifest_bumps(
    outdated: Iterable[Outdated],
    filename: str,
    sections: Iterable[str],
    edit: Edit,
    precision: Precision,
) -> Iterator[Bump]:
    """The bumps of JSON manifests, given the sections and the edit setting a range."""
    # read once per run, since the manifests change between runs
    load = cache(load_json)

    for package in outdated:
        manifest = load(Path(package.location, filename))
        project = manifest.get("name", package.location or filename)

        for section in sections:
            old = manifest.get(section, {}).get(package.name)

            if not isinstance(old, str) or old == (
                new := bump_range(old, package.latest, precision)
            ):
                continue

            yield Bump(
                project,
                section,
                package.name,
                (old,),
                (new,),
                *edit(package, section, new),
            )


def npm_outdated() -> Iterator[Outdated]:
    """The dependencies whose latest versions npm resolves outside their ranges."""
    # npm exits with 1 if anything is outdated
    match run_json("npm", "outdated", "--json", "--long", codes=(0, 1)):
        case {"error": {"summary": str(summary)}}:
            raise Error(summary)
        case dict(packages):
            # npm lists a dependency of several workspaces once per workspace
            entries = [
                (name, entry)
                for name, value in packages.items()
                for entry in (value if isinstance(value, list) else [value])
            ]
        case output:
            raise Error(f"Unexpected output of `npm outdated`: {output}")

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
    match run_json("composer", "outdated", "--direct", "--locked", "--format=json"):
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


def action_bumps(min_age: int, precision: Precision) -> Iterator[Bump]:
    """The bumps of the version tags of the GitHub Actions used by the workflows and composite actions."""
    # git skips ignored files, unlike a glob
    paths = sorted(map(Path, ls_files(*ACTION_PATHSPECS)))

    yield from tag_bumps(
        [
            Tagged(
                str(path.parent),
                path.name,
                action,
                action_repo(action),
                ref,
                Replace(path, line, f"{quote}{value}{quote}"),
                f"{quote}{action}@{PLACEHOLDER}{quote}",
            )
            for path in paths
            for line, value, quote in uses_values(compose(path))
            for action, sep, ref in [value.rpartition("@")]
            # local actions and docker images have no ref
            if sep
        ],
        min_age,
        precision,
    )


def action_repo(action: str) -> str:
    """The GitHub repository of an action, which may live in a directory of it."""
    return "/".join(action.split("/")[:2])


def compose(path: Path) -> yaml.Node | None:
    """The parsed YAML document of a file."""
    try:
        return yaml.compose(path.read_text(), Loader=yaml.SafeLoader)
    except yaml.YAMLError as error:
        raise Error(f"{path} holds no valid YAML: {error}") from error


def uses_values(node: yaml.Node | None) -> Iterator[tuple[int, str, str]]:
    """The values of the `uses` keys of a YAML document, with their lines and quotes."""
    match node:
        case yaml.MappingNode(value=list(pairs)):
            for key, value in pairs:
                match key, value:
                    case yaml.ScalarNode(value="uses"), yaml.ScalarNode(
                        value=str(text), start_mark=yaml.Mark(line=int(line))
                    ):
                        yield line, text, value.style or ""
                    case _:
                        yield from uses_values(value)
        case yaml.SequenceNode(value=list(items)):
            for item in items:
                yield from uses_values(item)


def flake_bumps(min_age: int, precision: Precision) -> Iterator[Bump]:
    """The bumps of the version tags of the GitHub inputs of a flake."""
    path = Path("flake.nix")
    inputs = run_json(
        "nix", "eval", "--json", "--file", str(path), "--apply", FLAKE_INPUTS
    )
    tagged: list[Tagged] = []

    for name, spec in inputs.items():
        match spec:
            case {
                "url": str(url),
                "ref": {
                    "type": "github",
                    "owner": str(owner),
                    "repo": str(repo),
                    "ref": str(ref),
                },
                "template": str(template),
                "pos": {"line": int(line)},
            }:
                # the url follows its attribute on the same line
                edit = Replace(path, line - 1, f'"{url}"')
                tagged.append(
                    Tagged(
                        ".",
                        "inputs",
                        name,
                        f"{owner}/{repo}",
                        ref,
                        edit,
                        f'"{template}"',
                    )
                )

    yield from tag_bumps(tagged, min_age, precision)


def tag_bumps(
    tagged: Sequence[Tagged], min_age: int, precision: Precision
) -> Iterator[Bump]:
    """The bumps of tagged refs, looked up concurrently per repository."""
    refs: dict[str, set[str]] = {}

    for item in tagged:
        refs.setdefault(item.repo, set()).add(item.ref)

    def resolve(repo: str) -> dict[str, str]:
        """The new tags of the refs of a repository, from its latest release, once their commits settled."""
        tag = latest_release(repo, min_age)
        return {
            ref: new
            for ref in refs[repo]
            if (new := bump_tag(repo, ref, tag, precision))
            and settled(repo, new, min_age)
        }

    with ThreadPoolExecutor() as pool:
        tags = dict(zip(refs, pool.map(resolve, refs)))

    for item in tagged:
        if new := tags[item.repo].get(item.ref):
            arg = item.template.replace(PLACEHOLDER, new)
            yield Bump(
                item.project,
                item.section,
                item.name,
                (item.ref,),
                (new,),
                item.edit,
                arg,
            )


def bump_tag(repo: str, ref: str, tag: str | None, precision: Precision) -> str | None:
    """The version tag of a GitHub repository replacing a ref, given its latest release, if it differs.

    The precision first shortens a full ref, such as `v7.0.1` to `v7`.
    Publishers do not always maintain floating tags, such as `v5` next to `v5.0.1`,
    but may maintain a floating branch instead, such as `v8` of `cycjimmy/semantic-release-action`,
    so the full tag of the release replaces the ref without either, if it is a newer one.
    """
    if tag is None:
        return None

    target = shorten(ref, precision)
    new = bump_range(target, tag)

    # releases may be published out of order, such as backports to an older major version
    if new == ref or Version(new) < Version(target):
        return None

    if new == tag or has_ref(repo, new):
        return new

    return tag if Version(tag) > Version(ref) else None


def shorten(ref: str, precision: Precision) -> str:
    """The ref cut to the components of a precision, unless it is shorter or no plain version.

    >>> shorten("v7.0.1", Precision(Level.MAJOR))
    'v7'
    >>> shorten("v0.29.1", Precision(Level.MAJOR))
    'v0.29'
    >>> shorten("v7", Precision(Level.MINOR))
    'v7'
    >>> shorten("v1.0.0-beta.1", Precision(Level.MAJOR))
    'v1.0.0-beta.1'
    """
    head, numbers, rest = parse(ref)

    if rest or not numbers:
        return ref

    return head + ".".join(map(str, numbers[: precision.length(numbers)]))


def latest_release(repo: str, min_age: int) -> str | None:
    """The tag of the newest stable release of a GitHub repository that is at least `min_age` days old."""
    cutoff = datetime.now(UTC) - timedelta(days=min_age)

    try:
        releases = run_json(
            "gh",
            "release",
            "list",
            f"--repo={repo}",
            "--exclude-drafts",
            "--exclude-pre-releases",
            "--json=tagName,publishedAt",
            capture=True,
        )
    except CommandError as error:
        # a missing or inaccessible repository only skips its refs, unlike a missing login with code 4
        if error.exit_code != 1:
            raise

        print(f"Skipping {repo}: {error.stderr}", file=sys.stderr)
        return None

    return next(
        (
            release["tagName"]
            for release in releases
            if datetime.fromisoformat(release["publishedAt"]) <= cutoff
        ),
        None,
    )


@cache
def has_ref(repo: str, name: str) -> bool:
    """Whether a GitHub repository has a tag or, failing that, a branch of a name."""
    return any(
        ref.get("ref") == f"refs/{kind}/{name}"
        for kind in ("tags", "heads")
        for ref in run_json(
            "gh", "api", f"repos/{repo}/git/matching-refs/{kind}/{name}", capture=True
        )
    )


@cache
def head(repo: str, ref: str) -> str:
    """The commit a ref of a GitHub repository points to, `HEAD` for its default branch."""
    return run(
        "gh", "api", f"repos/{repo}/commits/{ref}", "--jq=.sha", capture=True
    ).strip()


@cache
def branch_spans(repo: str, min_age: int) -> list[tuple[str, str]]:
    """The commits of the branches of a GitHub repository before and after their pushes and merges within the last `min_age` days."""
    cutoff = datetime.now(UTC) - timedelta(days=min_age)
    period = next((name for name, days in PERIODS.items() if days >= min_age), None)
    query = "per_page=100" + (f"&time_period={period}" if period else "")
    pages = run_json(
        "gh",
        "api",
        "--paginate",
        "--slurp",
        f"repos/{repo}/activity?{query}",
        capture=True,
    )

    spans: dict[str, tuple[str, str]] = {}

    # newest first, so a branch keeps its first `after` and its last `before`
    for activity in (activity for page in pages for activity in page):
        if (
            activity["after"] == NULL_COMMIT
            or datetime.fromisoformat(activity["timestamp"]) <= cutoff
        ):
            continue

        _, after = spans.get(activity["ref"], ("", activity["after"]))
        spans[activity["ref"]] = (activity["before"], after)

    return list(spans.values())


@cache
def contains(repo: str, tip: str, commit: str) -> bool:
    """Whether a commit is in the history of another one of a GitHub repository, which no unknown commit is."""
    if tip == commit:
        return True

    # an unknown commit fails with code 1, the commits beyond the first are of no interest
    status = run(
        "gh",
        "api",
        f"repos/{repo}/compare/{tip}...{commit}?per_page=1",
        "--jq=.status",
        codes=(0, 1),
        capture=True,
    )

    return status.strip() in ("behind", "identical")


def settled(repo: str, ref: str, min_age: int) -> bool:
    """Whether the commit of a ref of a GitHub repository reached a branch at least `min_age` days ago.

    Unlike the dates of commits and tags, which their authors choose, the activity log
    records with the time of the server when a push or merge moved a branch.
    A branch brought the commit if its newest head of that time has it but its oldest one lacks it,
    so a commit without a recent activity counts as settled,
    and a new branch only brings the commits missing from the default branch.
    """
    if min_age <= 0:
        return True

    commit = head(repo, ref)

    return not any(
        contains(repo, after, commit)
        and not contains(
            repo, head(repo, "HEAD") if before == NULL_COMMIT else before, commit
        )
        for before, after in branch_spans(repo, min_age)
    )


def relock(min_age: int) -> None:
    """Advance the floating refs of the lockfile, except for the workflows depending on a commit that has not settled yet."""
    lock = yaml.safe_load(ACTIONS_LOCK.read_text())
    workflows: Mapping[str, Sequence[str]] = lock.get("workflows") or {}
    dependencies: Mapping[str, Mapping[str, Any]] = lock.get("dependencies") or {}

    def unsettled(key: str) -> bool:
        """Whether the ref of a dependency moved to a commit that has not settled yet."""
        action, _, ref = key.rpartition("@")
        repo = action_repo(action)
        locked = dependencies[key]["commit"].partition("-")[2]

        return (
            min_age > 0
            and ref != locked
            and head(repo, ref) != locked
            and not settled(repo, ref, min_age)
        )

    def closure(keys: Iterable[str]) -> Iterator[str]:
        """The dependencies and their transitive ones."""
        for key in keys:
            yield key
            yield from closure(dependencies[key].get("uses") or ())

    with ThreadPoolExecutor() as pool:
        held = {
            key
            for key, hold in zip(dependencies, pool.map(unsettled, dependencies))
            if hold
        }

    for key in sorted(held):
        print(
            f"Holding back {key}, its new commit has not settled yet.", file=sys.stderr
        )

    paths = [path for path, keys in workflows.items() if held.isdisjoint(closure(keys))]

    if paths:
        run("gh-actions-lock", "--relock", *LOCK_FLAGS, *paths)


def python(mode: Mode) -> None:
    """Bump the ranges of a uv workspace, honoring settings such as `exclude-newer`."""
    mode.apply(uv_bumps(mode.precision))


def node(mode: Mode) -> None:
    """Bump the ranges of an npm or bun workspace with installed packages, honoring `min-release-age` of npm."""
    mode.apply(
        manifest_bumps(
            npm_outdated(), "package.json", NODE_SECTIONS, npm_edit, mode.precision
        )
    )


def php(mode: Mode) -> None:
    """Bump the ranges of a composer project."""
    mode.apply(
        manifest_bumps(
            composer_outdated(),
            "composer.json",
            PHP_SECTIONS,
            composer_edit,
            mode.precision,
        )
    )


def actions(mode: Mode) -> None:
    """Bump the version tags of the GitHub Actions in a repository at the chosen precision, then relock its `actions.lock` if it has one.

    The floating refs, such as `v7`, only advance once their new commits settled.
    """
    mode.apply(action_bumps(mode.min_age, mode.precision))

    if mode.dry_run or not ACTIONS_LOCK.is_file():
        return

    # locks the bumped refs and prunes the replaced ones
    run("gh-actions-lock", *LOCK_FLAGS)
    relock(mode.min_age)


def nix(mode: Mode) -> None:
    """Bump the version tags of the GitHub inputs of a flake at the chosen precision."""
    mode.apply(flake_bumps(mode.min_age, mode.precision))


@dataclass(frozen=True, slots=True)
class Ecosystem:
    """The range bumps of an ecosystem, with the pathspecs of the files they edit in a project."""

    bump: Callable[[Mode], None]
    pathspecs: Args


ECOSYSTEMS = {
    "python": Ecosystem(python, (":(glob)**/pyproject.toml",)),
    "node": Ecosystem(node, (":(glob)**/package.json",)),
    "php": Ecosystem(php, ("composer.json",)),
    "actions": Ecosystem(actions, ACTION_PATHSPECS),
    "nix": Ecosystem(nix, ("flake.nix",)),
}


@dataclass(frozen=True, slots=True)
class Command:
    """A command of a package manager, which only runs if the path `if_exists` exists, if given."""

    args: Args
    if_exists: str | None = None

    def __call__(self, message: str, env: Mapping[str, str]) -> None:
        """Run the command with the commit message in place of the placeholder in its arguments."""
        if self.if_exists is not None and not Path(self.if_exists).exists():
            return

        args = [arg.replace(MESSAGE, message) for arg in self.args]
        run(*args, output=False, env=os.environ | env)


@dataclass(frozen=True, slots=True)
class Manager:
    """A package manager of `bump update`, with the fields described by the module."""

    name: str
    lockfile: str
    excludes: Args = ()
    pathspecs: Args = ()
    ranges: str | None = None
    commands: tuple[Command, ...] = ()
    env: Mapping[str, str] = field(default_factory=dict)

    def update(self, mode: Mode) -> None:
        """Update and commit the projects at or below the working directory.

        The lockfiles are listed ahead of the updates, which may create others,
        and each project commits right away, so a parent never sweeps up the changes of a nested one.
        """
        excludes = (f":(exclude,glob){pattern}" for pattern in self.excludes)

        for lockfile in ls_files(f":(glob)**/{self.lockfile}", *excludes):
            with chdir(lockfile.removesuffix(self.lockfile) or "."):
                self.update_project(mode)

    def update_project(self, mode: Mode) -> None:
        """Update and commit the project in the working directory.

        The message names the project by its path in the repository unless it is the root.
        """
        prefix = run("git", "rev-parse", "--show-prefix").strip().removesuffix("/")
        message = f"chore(deps/{self.name}): update {prefix}".rstrip()
        head = run("git", "rev-parse", "HEAD")

        ranges = ECOSYSTEMS[self.ranges] if self.ranges is not None else None

        if ranges is not None:
            ranges.bump(mode)

        if mode.dry_run:
            return

        for command in self.commands:
            command(message, self.env)

        edited = ranges.pathspecs if ranges is not None else ()
        commit((self.lockfile, *self.pathspecs, *edited), message, head)


def commit(pathspecs: Iterable[str], message: str, head: str) -> None:
    """Commit the changed files that the pathspecs match, unless they are up to date.

    Pathspecs may match no file, such as optional manifests, since git only adds the files they match.
    A package manager may commit its lockfile itself since `head`, whose commit then takes up the remaining changes.
    """
    files = ls_files(*pathspecs)

    if not files:
        return

    run("git", "add", "--", *files)

    if not run("git", "diff", "--cached", "--name-only", "--", *files):
        return

    amend = run("git", "rev-parse", "HEAD") != head
    args = ("--amend", "--no-edit") if amend else ("--message", message)
    run("git", "commit", "--quiet", *args, "--", *files)


def load_config(data: Mapping[str, Any]) -> dict[str, Manager]:
    """The built-in package managers with those of a config, see the module docstring."""
    return MANAGERS | {
        name: Manager(
            name,
            spec["lockfile"],
            tuple(spec.get("excludes", ())),
            tuple(spec.get("pathspecs", ())),
            spec.get("ranges"),
            tuple(
                Command(tuple(command["args"]), command.get("ifExists"))
                for command in spec.get("commands", ())
            ),
            spec.get("env", {}),
        )
        for name, spec in data.items()
    }


# the package managers of flakes and GitHub Actions, which every project of them uses alike
MANAGERS = {
    "nix": Manager(
        "nix",
        "flake.lock",
        ranges="nix",
        # the summary of the lockfile updates goes into the body of the commit
        commands=(
            Command(
                (
                    "nix",
                    "flake",
                    "update",
                    "--commit-lock-file",
                    "--commit-lock-file-summary",
                    MESSAGE,
                )
            ),
        ),
    ),
    "actions": Manager("actions", str(ACTIONS_LOCK), ranges="actions"),
}
CONFIG = ConfigOption(
    load_config, MANAGERS, "JSON file of further package managers of `update`."
)


def update(managers: Mapping[str, Manager], names: Collection[str], mode: Mode) -> None:
    """Update the dependencies of the projects at or below the working directory and commit them per project and package manager.

    For each package manager, the projects with its lockfile bump their ranges, run its commands,
    and commit the lockfile with the other files it changes as `chore(deps/<manager>): update[ <path>]`,
    amending the commit if a command already made one, such as `nix flake update --commit-lock-file`.
    """
    for name, manager in managers.items():
        if not names or name in names:
            manager.update(mode)


def parser(managers: Collection[str] = ()) -> argparse.ArgumentParser:
    """The parser of the global options followed by a command with its own options, choosing among the package managers."""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=HelpFormatter, parents=[CONFIG.parser()]
    )

    options = argparse.ArgumentParser(add_help=False)
    options.add_argument(
        "--accept",
        type=Level,
        choices=list(Level),
        help="Accept the bumps up to this level without prompting and skip the others, so `minor` skips the major ones.",
    )
    options.add_argument(
        "--qualified",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Only bump full versions such as `1.2.3`, leaving floating ones such as `v2` or `^1.2` alone.",
    )
    options.add_argument(
        "--precision",
        type=Level,
        choices=list(Level),
        default=Level.MAJOR,
        help="Write the moved versions with at most this precision, counted like the levels, such as `^4` for `major`, unless that allows older versions, while version tags such as `v7.0.1` shorten to their floating tag `v7` even without a newer release. `patch` keeps the precision of versions with up to three components.",
    )
    # a pair of flags instead of `--no-zero-major` to keep their names symmetric
    zero = options.add_mutually_exclusive_group()
    zero.add_argument(
        "--zero-major",
        action="store_true",
        help="Whether a change after leading zeros, such as from `0.29.1` to `0.30.0`, is a major or a minor one.",
    )
    zero.add_argument("--zero-minor", dest="zero_major", action="store_false")
    options.set_defaults(zero_major=True)
    # a string default goes through `type` like a passed value
    options.add_argument(
        "--min-age",
        type=int,
        default=os.environ.get("BUMP_MIN_AGE", "0"),
        help="Days a release of a GitHub Action or flake input must age before it is offered, also set by `BUMP_MIN_AGE`.",
    )
    options.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="List the bumps that would be applied without applying them, so `update` runs no commands.",
    )

    commands = parser.add_subparsers(
        title="commands", dest="command", metavar="COMMAND"
    )
    update_parser = add_command(commands, "update", update.__doc__, parents=[options])
    update_parser.add_argument(
        "managers",
        nargs="*",
        choices=managers,
        metavar="MANAGER",
        help="Package managers to run, defaulting to all.",
    )

    ranges = add_command(commands, "ranges", RANGES_DOC, parents=[options])
    ecosystems = ranges.add_subparsers(
        title="ecosystems", dest="ecosystem", metavar="ECOSYSTEM", required=True
    )

    for name, ecosystem in ECOSYSTEMS.items():
        add_command(ecosystems, name, ecosystem.bump.__doc__)

    return parser


@entrypoint
def main() -> None:
    """Parse the command line and run the chosen command."""
    managers = CONFIG.parse()
    cli = complete(parser(managers))
    args = cli.parse_args()

    # global options precede the command, so it can be appended
    if args.command is None:
        args = cli.parse_args([*sys.argv[1:], "update"])

    mode = Mode(
        args.accept,
        args.qualified,
        Precision(args.precision, args.zero_major),
        args.dry_run,
        args.min_age,
    )

    match args.command:
        case "ranges":
            ECOSYSTEMS[args.ecosystem].bump(mode)

        case "update":
            update(managers, args.managers, mode)


if __name__ == "__main__":
    main()
