---
name: my-sandbox
description: |
  Diagnoses an operation that the nono sandbox may have denied and offers the user the ways to grant it.
  The argument names the failed path, host, or command and defaults to the last failure.
  Use when a file, network, or command operation fails with a permission error, or when the user asks what the sandbox allows.
---

Confirm a denial with nono before concluding anything, then report it instead of working around it.
This only applies when `$NONO_CAP_FILE` is set, otherwise the agent runs outside nono, for example in a desktop app.

## Scope

The agent runs inside nono with the profile `agents` or one extending it, so its own sandbox is disabled and nono is the boundary.
The working directory and every directory listed in `$NONO_ALLOW` or granted with `nono run --allow` are writable.
Beyond them, only system paths, the nix store, caches, the git directory of a linked worktree, and the state of the agent are accessible, and network access goes through a proxy with a domain allowlist.

In every workspace, these paths are read-only:

- the git config, hooks, and info, submodules and worktrees included, and `.gitmodules`
- hook manager configs such as `.pre-commit-config.yaml` and `lefthook.yml`, `.husky`, `.envrc`, `.direnv`, and `.devcontainer`
- editor and agent settings such as `.vscode`, `.zed`, `.idea`, `.claude`, `.codex`, `.opencode`, `.vibe`, `opencode.json`, and `.mcp.json`

Within the agent directories, prompts such as skills, commands, subagents, rules, and output styles stay writable, and so do the worktrees and subagent memory of claude.
On macOS, these rules apply at any depth, except in temporary directories and caches, so `git init` and `git clone` only work there.
On Linux, they only apply at the workspace roots and their git directories, to paths that existed when the agent started.

A `.git` cannot be moved or deleted, and `.env` files other than `.env.example` are unreadable.
The managed config in the state directories of the agents, such as their settings, instructions, and skills, is read-only as well.

## Tools

```sh
nono why --self --path <path> --op read
nono why --self --path <path> --op write
nono why --self --host <host>
```

`$NONO_CAP_FILE` points to a JSON file with the current capabilities.
`nono why` does not know the protected workspace paths above, so a denial there is expected and needs no diagnosis.

## Steps

1. Run `nono why` for the failed path or host, since generic errors such as `Operation not permitted` do not prove a sandbox denial.
2. On `DENIED`, do not retry, and do not work around it through another path, a copy, a different tool, or the user's terminal.
   Do not suggest chmod, sudo, or Full Disk Access either.
3. Never edit the profiles in `~/.config/nono/profiles` or run `nono profile promote`, only the user may grant access.

## Output

Report what was denied and the rule from `nono why`, then offer these options.

1. For a one-off directory, the user restarts the agent with it added, `NONO_ALLOW=/path/to/dir <agent>`, which grants read and write access.
2. For anything else, such as read-only access, a file, or a host, request it as a profile draft, see below.
3. For a lasting need, the user changes the `programs.agents.sandbox` options in `modules/programs/agents` of the infra repository and rebuilds.
4. If nono itself is at fault, the user restarts the agent with `NO_NONO=1 <agent>`, which runs it within its native sandbox instead.

## Profile Drafts

A draft requests more access, and nothing applies it before the user reviews it outside of nono.

1. Run `nono profile guide` for the schema.
2. Write the draft to `~/.config/nono/profile-drafts/agents-<topic>.json` with `"meta": {"name": "agents-<topic>"}` and `"extends": "agents"`, granting only what the task needs, such as `filesystem.read`, `filesystem.allow`, or `network.allow_domain`.
3. Run `nono profile validate --draft agents-<topic>`.
4. Tell the user to run `nono profile promote agents-<topic>`, which shows the diff and asks for confirmation, and to restart the agent with `NONO_PROFILE=agents-<topic> <agent>`.

The absolute denies of the sandbox and the read-only workspace paths above still apply under a promoted profile.
