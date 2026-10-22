"""Run an agent harness within nono, or directly when inside it already or `NO_NONO` is set.

The directories of the comma-separated `NONO_ALLOW` are granted by nono and passed
to the harness through its add-dir flag, as are those the arguments give through it.
"""

import argparse
import json
import os
import signal
import subprocess
import tempfile
from collections.abc import Iterable, Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Self

from infra_apps.apptools import HelpFormatter, entrypoint
from infra_apps.bwrap import Policy
from infra_apps.bwrap import command as bwrap_command


@dataclass(frozen=True, slots=True)
class Config:
    """The launch configuration of a harness.

    Attributes:
        harness: Absolute path of the harness executable.
        nono: Absolute path of nono, since `PATH` reaches the harness, as for every executable.
        profile: nono profile the session extends unless `NONO_PROFILE` is set.
        herdr_agent: Label by which herdr identifies the harness on nono.
        sandbox_args: Arguments prepended to those of the harness.
        trailing_args: Arguments appended to those of the harness.
        add_dir_flag: Flag of the harness adding a workspace directory.
        ancestor_rule: Seatbelt rule for the ancestors of every workspace directory,
            with `{}` for the JSON-encoded path, null outside of macOS.
        bwrap: Policy of the bubblewrap sandbox around nono, null outside of Linux.
    """

    harness: str
    nono: str
    profile: str
    herdr_agent: str
    sandbox_args: Sequence[str]
    trailing_args: Sequence[str]
    add_dir_flag: str | None
    ancestor_rule: str | None
    bwrap: Policy | None

    @classmethod
    def load(cls, path: str) -> Self:
        """Read the configuration from the JSON file at `path`."""
        data = json.loads(Path(path).read_bytes())
        bwrap = data.pop("bwrap")

        return cls(**data, bwrap=None if bwrap is None else Policy.parse(bwrap))


def split(value: str) -> list[str]:
    """The non-empty entries of a comma-separated list.

    >>> split("a,,b,")
    ['a', 'b']
    """
    return [entry for entry in value.split(",") if entry]


def flag_values(flag: str, args: Iterable[str]) -> Iterator[str]:
    """The values given through `flag` in `args`, either separate or after `=`.

    >>> list(flag_values("--add-dir", ["--add-dir", "a", "--add-dir=b", "c"]))
    ['a', 'b']
    """
    prev = None

    for arg in args:
        if prev == flag:
            yield arg
        elif arg.startswith(f"{flag}="):
            yield arg.removeprefix(f"{flag}=")

        prev = arg


def ancestors(dirs: Iterable[str]) -> list[str]:
    """The sorted ancestors of the existing directories, except for `/`."""
    paths: set[str] = set()

    for entry in dirs:
        path = Path(entry).resolve()

        if path.is_dir():
            paths.update(str(parent) for parent in path.parents[:-1])

    return sorted(paths)


def write_profile(extends: str, rule: str, path: Path, dirs: Iterable[str]) -> None:
    """Write a session profile extending another, granting to list the ancestors of `dirs`."""
    profile = {
        "meta": {"name": "agents-session"},
        "extends": extends,
        "unsafe_macos_seatbelt_rules": [
            rule.format(json.dumps(ancestor, ensure_ascii=False))
            for ancestor in ancestors(dirs)
        ],
    }
    path.write_text(json.dumps(profile, ensure_ascii=False, indent=2))


def run(command: Sequence[str], env: dict[str, str]) -> int:
    """Run `command` as a child, forwarding termination requests to it.

    The terminal signals its whole process group, so the child gets those on its own.
    """
    process = subprocess.Popen(command, env=env)

    for sig in (signal.SIGINT, signal.SIGQUIT):
        signal.signal(sig, signal.SIG_IGN)

    for sig in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, lambda signum, _: process.send_signal(signum))

    return process.wait()


def launch(config: Config, args: Sequence[str]) -> int:
    """Launch the harness of `config` with `args`, returning its exit status."""
    # the native sandbox of the harness instead, in case nono gets in the way
    if os.environ.get("NO_NONO"):
        os.execv(config.harness, [config.harness, *args])

    allowed = split(os.environ.get("NONO_ALLOW", ""))
    flag = config.add_dir_flag
    added = [arg for path in allowed for arg in (flag, path)] if flag else []
    harness = [
        config.harness,
        *config.sandbox_args,
        *added,
        *args,
        *config.trailing_args,
    ]

    # nono sets NONO_CAP_FILE in every sandbox it starts.
    if Path(os.environ.get("NONO_CAP_FILE", "")).is_file():
        os.execv(config.harness, harness)

    if flag:
        allowed += flag_values(flag, args)

    env = dict(os.environ)

    if allowed:
        env["NONO_ALLOW"] = ",".join(allowed)

    # A private temporary directory, the only place the session may bind and connect sockets,
    # such as the forkserver of Python's multiprocessing. Those of /tmp and the host stay out of reach.
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        # Without `O_PATH`, Nix and Bun open every ancestor of a path they resolve.
        if config.ancestor_rule is not None:
            profile = Path(tmp, "profile.json")
            extends = os.environ.get("NONO_PROFILE") or config.profile
            write_profile(extends, config.ancestor_rule, profile, [".", *allowed])
            env["NONO_PROFILE"] = str(profile)

        # The agent runs on a pty of nono, so herdr identifies it by this hint on nono.
        env |= {"TMPDIR": tmp, "HERDR_AGENT": config.herdr_agent}
        roots = [Path.cwd(), *map(Path, allowed)]
        sandbox = [] if config.bwrap is None else bwrap_command(config.bwrap, roots)
        status = run(
            [
                *sandbox,
                config.nono,
                "--silent",
                "run",
                "--no-audit",
                "--allow-cwd",
                "--allow-unix-socket-subtree-bind",
                tmp,
                "--",
                *harness,
            ],
            env,
        )

    # the shell convention for a death by signal
    return 128 - status if status < 0 else status


def parser() -> argparse.ArgumentParser:
    """The parser of the command line."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=HelpFormatter)
    parser.add_argument("--config", type=Config.load, required=True)
    parser.add_argument("args", nargs="*")

    return parser


@entrypoint
def main() -> int:
    """Parse the arguments and launch the harness."""
    args = parser().parse_args()

    return launch(args.config, args.args)


if __name__ == "__main__":
    main()
