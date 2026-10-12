---
name: my-sandbox
description: |
  Diagnoses an operation that the nono sandbox may have denied and offers the user the ways to grant it.
  The argument names the failed path, host, or command and defaults to the last failure.
  Use when a file, network, or command operation fails with a permission error, or when the user asks what the sandbox allows.
---

Confirm a denial with nono before concluding anything, then report it instead of working around it.
This only applies when `$NONO_CAP_FILE` is set, otherwise the agent runs outside nono.

## Scope

nono confines the agent with the profile `agents` or one extending it, so the native sandbox of the agent is off.
The working directory and the directories in `$NONO_ALLOW` are writable, and network access goes through a proxy that enforces the allowed and denied domains of the profile.
Localhost may be open, so local dev servers and models are reachable directly, and Unix sockets work within `/tmp` and `$TMPDIR`.
Within every workspace, files that configure code running outside the sandbox later, such as git hooks or editor and agent settings, are read-only, and `.env` files are unreadable.

## Tools

```sh
nono why --self --path <path> --op <read|write>
nono why --self --host <host>
# the resolved profile, including the rules for the protected workspace paths on macOS
nono profile show agents
```

`$NONO_CAP_FILE` points to a JSON file with the current capabilities.
`nono why` misses the protected workspace paths, which macOS enforces through the raw seatbelt rules of the profile and Linux through the bubblewrap policy that the agent wrapper on `PATH` passes to `nono-bwrap`.

## Steps

1. Check the failed path or host with the tools, since generic errors such as `Operation not permitted` do not prove a sandbox denial.
2. On a denial, do not retry or work around it through another path, a copy, a different tool, or the terminal of the user, and do not suggest chmod, sudo, or Full Disk Access.
3. Never edit the profiles in `~/.config/nono/profiles` or run `nono profile promote`, only the user may grant access.

## Output

Report what was denied and the rule behind it, then offer these options.

1. For a one-off directory, the user restarts the agent with `<agent> --add-dir /path/to/dir` or `NONO_ALLOW=/path/to/dir <agent>`, which grants read and write access.
2. For read-only access, a file, or a host, request a profile draft, see below.
3. For a lasting need, the user changes the `programs.agents.sandbox` options in `modules/programs/agents` of the infra repository and rebuilds.
4. If nono itself is at fault, the user restarts the agent with `NO_NONO=1 <agent>` to use its native sandbox instead.

## Profile Drafts

1. Run `nono profile guide` for the schema.
2. Write `~/.config/nono/profile-drafts/agents-<topic>.json` with `"meta": {"name": "agents-<topic>"}` and `"extends": "agents"`, granting only what the task needs, such as `filesystem.read`, `filesystem.allow`, or `network.allow_domain`.
3. Run `nono profile validate --draft agents-<topic>`.
4. Tell the user to run `nono profile promote agents-<topic>`, which shows the diff and asks for confirmation, and to restart the agent with `NONO_PROFILE=agents-<topic> <agent>`.

A promoted profile cannot lift the absolute denies or the protected workspace paths.
