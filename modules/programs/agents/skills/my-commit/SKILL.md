---
name: my-commit
description: |
  Splits uncommitted changes into atomic commits, one logical change each, down to single lines within a file.
  The argument narrows the paths and defaults to the whole working tree.
  Use when the user asks to commit, to split changes into atomic commits, or to amend unpushed commits.
---

Turn the working tree into a sequence of commits where each one does a single thing and can be reverted alone.
Invoking this skill is the permission to commit, but never push, and never modify the working tree.
Only amend when the user asks, and only commits that are not on any remote.

## Scope

The paths from the argument, or the whole working tree, including untracked files.
Read the whole change before grouping it.

## Tools

```sh
# intent-to-add, so untracked files show up in the diff
git add -N <paths>
git diff HEAD <paths>

# the scopes the repository already uses
git log --oneline -10

# stage part of a file, after dropping the lines of other commits from the patch
git diff <file> > $TMPDIR/slice.patch
git apply --cached --recount $TMPDIR/slice.patch

# the commits that are not on any remote, the only ones that may be amended
git log --oneline HEAD --not --remotes

# amend the last commit, or an earlier one through a fixup
git commit --amend --no-edit
git commit --fixup=<commit>
git rebase --autosquash --autostash <commit>~
```

To drop a line from the patch, delete it if it starts with `+`, or change its `-` to a space.
Never touch context lines.

## Steps

1. Group the hunks, and the lines inside a hunk, into commits.
   - One reason per commit. If the message needs an "and", split further.
   - Keep refactors and formatting apart from behavior changes.
   - Keep generated files and lockfiles with the change that produced them.
   - Order commits so that each one only depends on earlier ones.
   - Leave debug output and scratch files uncommitted.
2. For each commit, stage whole files with `git add` and partial files through a patch.
3. Check `git diff --cached` holds exactly that commit.
4. Commit with `git commit -m "<type>(<scope>): <title>"`, a conventional message with a concise title and an empty body.
   When the user asked to amend and the change belongs to an unpushed commit, amend that commit instead.
   Never use `--no-verify`, and when a hook fails, fix the issue and commit again.

## Output

List the commits created or amended, oldest first, and the changes left uncommitted with the reason.
