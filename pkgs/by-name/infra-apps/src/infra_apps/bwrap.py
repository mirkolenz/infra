"""The bubblewrap command enforcing the agent sandbox where nono only grants, for `nono_launch`.

On Linux, nono grants but does not restrict within granted directories, so bubblewrap mounts
over the `read` paths within writable ones, the `write` paths within those,
and the workspace keys of every workspace root and its git directories.
The workspace roots are the working directory and the granted directories.
The mounts cover paths that exist at launch.
"""

import subprocess
from collections.abc import Iterable, Iterator, Mapping
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Any, Self

__all__ = ["Policy", "command"]

GIT_DIR_PREFIX = ".git/"


class Access(StrEnum):
    """Access to a path, in the order of precedence, so `write` exempts from the others."""

    WRITE = "write"
    DENY = "deny"
    READ = "read"


@dataclass(frozen=True, slots=True)
class Policy:
    """The workspace keys by access, the absolute sandbox paths, and the executables.

    The executables are absolute paths, since `PATH` reaches the sandboxed command.
    """

    workspace: Mapping[Access, tuple[str, ...]]
    read: tuple[Path, ...]
    write: tuple[Path, ...]
    bwrap: str
    git: str

    @classmethod
    def parse(cls, data: Mapping[str, Any]) -> Self:
        """The policy of its JSON object."""
        return cls(
            workspace={
                Access(access): tuple(keys)
                for access, keys in data["workspace"].items()
            },
            read=tuple(map(Path, data["read"])),
            write=tuple(map(Path, data["write"])),
            bwrap=data["bwrap"],
            git=data["git"],
        )

    def keys(self, access: Access, *, git: bool) -> list[str]:
        """The workspace keys with `access`, those within a git directory relative to it."""
        return [
            key.removeprefix(GIT_DIR_PREFIX)
            for key in sorted(self.workspace[access])
            if key.startswith(GIT_DIR_PREFIX) == git
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
    def discover(cls, roots: Iterable[Path], git: str) -> Self:
        """The workspace of the existing directories among `roots`, found with `git`."""
        dirs = {path for root in roots if (path := root.resolve()).is_dir()}
        processes = [
            subprocess.Popen(
                [
                    git,
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

    yield from (Mount(Access.READ, path) for path in policy.read if path.exists())
    yield from (Mount(Access.WRITE, path) for path in policy.write if path.exists())


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


def command(policy: Policy, roots: Iterable[Path]) -> list[str]:
    """The bubblewrap command enforcing `policy` for the workspace roots, up to the `--` before the command it runs."""
    workspace = Workspace.discover(roots, policy.git)
    args = [
        arg for mount in canonical(requested(policy, workspace)) for arg in mount.args
    ]

    return [policy.bwrap, "--dev-bind", "/", "/", "--die-with-parent", *args, "--"]
