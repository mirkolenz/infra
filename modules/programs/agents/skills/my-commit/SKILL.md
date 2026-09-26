---
name: my-commit
description: |
  Splits uncommitted changes into atomic commits, one logical change each, down to single lines within a file.
  The argument narrows the paths and defaults to the whole working tree.
  Use when the user asks to commit, or to split changes into atomic commits.
---

Turn the working tree into a sequence of commits where each one does a single thing and can be reverted alone.
Invoking this skill is the permission to commit, but never push, never rewrite existing commits, and never modify the working tree.

## Plan

Read the whole change before grouping it.
Run `git add -N .` first so untracked files show up in the diff.

```sh
git add -N .
git diff HEAD
git log --oneline -10
```

Group the hunks, and the lines inside a hunk, into commits.

- One reason per commit. If the message needs an "and", split further.
- Keep refactors and formatting apart from behavior changes.
- Keep generated files and lockfiles with the change that produced them.
- Order commits so that each one only depends on earlier ones.
- Leave debug output and scratch files uncommitted.

## Commit

For each commit, stage only its changes, verify, and commit.

```sh
git add <whole files>
git diff <partial file> > $TMPDIR/slice.patch   # remove the lines of other commits
git apply --cached --recount $TMPDIR/slice.patch
git diff --cached --stat
git commit -m "<type>(<scope>): <title>"
```

To remove a line from the patch, delete it if it starts with `+`, or change its `-` to a space.
Never touch context lines.

Use a conventional commit message that matches the scopes in `git log`, with a concise title and an empty body.
Never use `--no-verify`, and when a hook fails, fix the issue and commit again.

## Output

List the commits created, oldest first, and the changes left uncommitted with the reason.
