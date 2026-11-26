"""Run an agent harness within nono, or directly when inside it already or `NO_NONO` is set.

The directories of the comma-separated `NONO_ALLOW` are granted by nono and passed
to the harness through its add-dir flag, as are those the arguments give through it.
"""

import argparse
import json
import os
import signal
import subprocess
import sys
import tempfile
from collections.abc import Iterable, Iterator, Mapping, Sequence
from contextlib import suppress
from dataclasses import dataclass
from pathlib import Path
from string import Template
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
        profile: nono profile of the installation, which the session extends below the draft `NONO_PROFILE` names.
        herdr_agent: Label by which herdr identifies the harness on nono.
        sandbox_args: Arguments prepended to those of the harness.
        trailing_args: Arguments appended to those of the harness.
        add_dir_flag: Flag of the harness adding a workspace directory.
        env_files: Variables set by nono from readable, non-empty source files.
        env_templates: Variables set within nono from templates over the environment nono gives,
            skipped while one they reference is unset.
        granted: Absolute paths the profile grants, whose ancestors the session lists on macOS.
        bwrap: Policy of the bubblewrap sandbox around nono, null outside of Linux.
    """

    harness: str
    nono: str
    profile: str
    herdr_agent: str
    sandbox_args: Sequence[str]
    trailing_args: Sequence[str]
    add_dir_flag: str | None
    env_files: Mapping[str, str]
    env_templates: Mapping[str, str]
    granted: Sequence[str]
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
    prefix = f"{flag}="

    for arg in args:
        if prev == flag:
            yield arg
        elif arg.startswith(prefix):
            yield arg.removeprefix(prefix)

        prev = arg


def ancestors(paths: Iterable[Path]) -> list[str]:
    """The sorted ancestors of `paths` that are existing directories, except for `/`.

    nono resolves their symlinks itself, so the paths stay as given.
    """
    parents = {parent for path in paths for parent in path.absolute().parents[:-1]}

    return sorted(str(parent) for parent in parents if parent.is_dir())


def env_credentials(files: Mapping[str, str]) -> list[str]:
    """Map readable, non-empty regular files to environment variables through nono.

    >>> env_credentials({"A": "/dev/null", "B": "/nonexistent"})
    []
    """
    args: list[str] = []

    for var, path in files.items():
        file = Path(path)

        if not file.is_file():
            continue

        try:
            with file.open("rb") as source:
                if not source.read(1):
                    continue
        except OSError:
            continue

        args += ["--env-credential-map", f"file://{file}", var]

    return args


def sandbox_env(env: Mapping[str, str], templates: Mapping[str, str]) -> dict[str, str]:
    """The environment of the harness within nono, derived from that nono gives it.

    nono exempts only `localhost` and `127.0.0.1` from its proxy, which drops requests to `::1`.
    The profile cannot add it, nono sets the variables after `environment.set_vars`
    and refuses `network.no_proxy` with the network namespace on Linux.
    Node's fetch before v26 (undici 8.10) also needs `[::1]`, but httpx crashes on it.
    TODO: drop once nono exempts `::1` itself

    >>> env = sandbox_env({"NO_PROXY": "localhost,::1", "A": "a"}, {"B": "b=$A", "C": "$D"})
    >>> env["NO_PROXY"], env["no_proxy"], env["B"], "C" in env
    ('localhost,::1', '::1', 'b=a', False)
    """
    result = dict(env)

    for var in ("NO_PROXY", "no_proxy"):
        hosts = split(env.get(var, ""))
        result[var] = ",".join(hosts if "::1" in hosts else [*hosts, "::1"])

    for var, template in templates.items():
        with suppress(KeyError):
            result[var] = Template(template).substitute(env)

    return result


def write_profile(extends: Sequence[str], path: Path, paths: Iterable[Path]) -> None:
    """Write a session profile extending `extends` from left to right, granting to list the ancestors of `paths`.

    The profiles are merged in the order given, so a later one takes precedence.

    On macOS, nono grants a directory in `read_file` as its exact path, which lists its entries only.
    Its ancestors include those of nono's state, which Seatbelt still denies.
    TODO: the list-only grant of nono once it has one, https://github.com/nolabs-ai/nono/issues/457
    """
    profile = {
        "meta": {"name": "agents-session"},
        "extends": list(extends),
        "allow_parent_of_protected": True,
        "filesystem": {"read_file": ancestors(paths)},
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
    given: list[str] = []
    added: list[str] = []

    if flag := config.add_dir_flag:
        given = list(flag_values(flag, args))
        added = [arg for path in allowed if path not in given for arg in (flag, path)]

    # nono sets NONO_CAP_FILE in every sandbox it starts, such as the one this launcher runs itself in.
    if Path(os.environ.get("NONO_CAP_FILE", "")).is_file():
        harness = [
            config.harness,
            *config.sandbox_args,
            *added,
            *args,
            *config.trailing_args,
        ]
        os.execve(
            config.harness, harness, sandbox_env(os.environ, config.env_templates)
        )

    allowed += given

    roots = [Path.cwd(), *map(Path, allowed)]
    env = dict(os.environ)

    if allowed:
        env["NONO_ALLOW"] = ",".join(allowed)

    # The profile of the installation, below a draft that `NONO_PROFILE` names,
    # so a draft never reaches the paths of another installation.
    extends = [config.profile]

    if draft := os.environ.get("NONO_PROFILE"):
        extends.append(draft)

    # A private temporary directory, the only place the session may bind and connect sockets,
    # such as the forkserver of Python's multiprocessing. Those of /tmp and the host stay out of reach.
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        profile = Path(tmp, "profile.json")
        # On macOS, without `O_PATH`, Nix and Bun open every ancestor of a path they resolve.
        listed = (
            [*roots, *map(Path, config.granted)] if sys.platform == "darwin" else []
        )
        write_profile(extends, profile, listed)

        # The agent runs on a pty of nono, so herdr identifies it by this hint on nono.
        env |= {
            "NONO_PROFILE": str(profile),
            "TMPDIR": tmp,
            "HERDR_AGENT": config.herdr_agent,
        }
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
                *env_credentials(config.env_files),
                "--",
                # this launcher again, which runs the harness within the sandbox
                sys.executable,
                *sys.orig_argv[1:],
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
