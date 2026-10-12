"""Run a command within bubblewrap, enforcing the agent sandbox where nono only grants.

On Linux, nono grants but does not deny within granted directories, so bubblewrap mounts
over the `deny`, `read` and `write` paths, the relative keys of every workspace root and
its git directories, and the blocked commands on `PATH`. The workspace roots are the
working directory and those of `NONO_ALLOW`. The mounts cover paths that exist at launch,
so a fresh copy of a blocked command, such as one from `nix run`, still runs.
"""

import json
import os
import subprocess
from collections.abc import Iterable, Iterator, Mapping
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Annotated, Self

import typer

# Absolute paths, since `PATH` reaches the command.
BWRAP = "@bwrap@"
GIT = "@git@"

GIT_DIR_PREFIX = ".git/"


class Access(StrEnum):
    """Access to a path, in the order of precedence, so `write` exempts from the others."""

    WRITE = "write"
    DENY = "deny"
    READ = "read"


@dataclass(frozen=True, slots=True)
class Policy:
    """The relative and absolute sandbox paths and the commands nono blocks."""

    relative: Mapping[str, Access]
    deny: tuple[Path, ...]
    read: tuple[Path, ...]
    write: tuple[Path, ...]
    blocked_commands: frozenset[str]

    @classmethod
    def load(cls, path: Path) -> Self:
        """Read the policy from the JSON file at `path`."""
        data = json.loads(path.read_bytes())

        return cls(
            relative={key: Access(value) for key, value in data["relative"].items()},
            deny=tuple(map(Path, data["deny"])),
            read=tuple(map(Path, data["read"])),
            write=tuple(map(Path, data["write"])),
            blocked_commands=frozenset(data["blocked_commands"]),
        )

    def keys(self, access: Access, *, git: bool) -> list[str]:
        """The relative keys with `access`, those within a git directory relative to it."""
        return [
            key.removeprefix(GIT_DIR_PREFIX)
            for key, value in sorted(self.relative.items())
            if value is access and key.startswith(GIT_DIR_PREFIX) == git
        ]


@dataclass(frozen=True, slots=True)
class Mount:
    """A bubblewrap mount enforcing `access` on `path`."""

    access: Access
    path: Path

    @property
    def args(self) -> list[str]:
        """The bubblewrap arguments of the mount."""
        path = str(self.path)

        match self.access:
            case Access.WRITE:
                return ["--bind", path, path]
            case Access.READ:
                return ["--ro-bind", path, path]
            case Access.DENY if self.path.is_dir():
                return ["--tmpfs", path]
            case Access.DENY:
                return ["--ro-bind", "/dev/null", path]


@dataclass(frozen=True, slots=True)
class Workspace:
    """The working trees and git directories of the workspace roots."""

    trees: frozenset[Path]
    gitdirs: frozenset[Path]

    @classmethod
    def discover(cls, roots: Iterable[Path]) -> Self:
        """The workspace of the existing directories among `roots`."""
        dirs = {path for root in roots if (path := root.resolve()).is_dir()}
        processes = [
            subprocess.Popen(
                [
                    GIT,
                    "-C",
                    str(path),
                    "rev-parse",
                    "--path-format=absolute",
                    "--show-toplevel",
                    "--git-dir",
                    "--git-common-dir",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
            for path in dirs
        ]
        trees = set(dirs)
        gitdirs: set[Path] = set()

        for process in processes:
            stdout, _ = process.communicate()

            if process.returncode == 0 and len(lines := stdout.splitlines()) == 3:
                toplevel, gitdir, common = map(Path, lines)
                trees.add(toplevel)
                gitdirs.update((gitdir, common))

        # the home directory itself holds the state of the agents
        trees.discard(Path.home().resolve())

        return cls(frozenset(trees), frozenset(gitdirs))


def executables(name: str) -> Iterator[Path]:
    """Every canonical executable on `PATH` called `name`, except a multi-call binary such
    as coreutils, which would take its other commands along."""
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(directory or ".", name)

        if candidate.is_file() and os.access(candidate, os.X_OK):
            target = candidate.resolve()

            if target.name == name:
                yield target


def requested(policy: Policy, workspace: Workspace) -> Iterator[Mount]:
    """The mounts of the existing paths, in the order of precedence."""
    bases = [(tree, False) for tree in sorted(workspace.trees)]
    bases += [(gitdir, True) for gitdir in sorted(workspace.gitdirs)]

    for base, git in bases:
        for access in Access:
            for key in policy.keys(access, git=git):
                yield from (Mount(access, path) for path in sorted(base.glob(key)))

        # A bind onto itself keeps a git directory in place, renaming it fails with EBUSY.
        if git:
            yield Mount(Access.WRITE, base)

    yield from (Mount(Access.DENY, path) for path in policy.deny if path.exists())
    yield from (Mount(Access.READ, path) for path in policy.read if path.exists())
    yield from (Mount(Access.WRITE, path) for path in policy.write if path.exists())

    for name in sorted(policy.blocked_commands):
        yield from (Mount(Access.DENY, path) for path in executables(name))


def canonical(mounts: Iterable[Mount]) -> list[Mount]:
    """The first access set for each canonical path, parents before their children,
    whose mounts then apply on top. bubblewrap mounts neither on nor below a symlink,
    so a deny mounts on its target and other paths with one are skipped."""
    accesses: dict[Path, Access] = {}

    for mount in mounts:
        path = mount.path.resolve()

        if mount.access is Access.DENY or path == mount.path:
            accesses.setdefault(path, mount.access)

    return [
        Mount(access, path)
        for path, access in sorted(accesses.items(), key=lambda item: item[0].parts)
    ]


def main(
    policy: Annotated[Path, typer.Option(exists=True, dir_okay=False)],
    command: list[str],
) -> None:
    """Run `command` within bubblewrap mounts for the workspace roots."""
    allowed = os.environ.get("NONO_ALLOW", "").split(",")
    workspace = Workspace.discover(
        [Path.cwd(), *(Path(root) for root in allowed if root)]
    )
    parsed = Policy.load(policy)
    args = [
        arg for mount in canonical(requested(parsed, workspace)) for arg in mount.args
    ]

    os.execv(
        BWRAP,
        [BWRAP, "--dev-bind", "/", "/", "--die-with-parent", *args, "--", *command],
    )


if __name__ == "__main__":
    typer.run(main)
