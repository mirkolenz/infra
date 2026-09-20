# Target

The argument names the target, defaulting to uncommitted changes.

- nothing, `diff`: `git diff HEAD` and the untracked files
- `staged`: `git diff --staged`
- `last`: `git show HEAD`
- a revision, a range, or a branch: `git diff <arg>`
- `pr`, `pr <number>`: `gh pr diff <number>`
- `all`, or a path: the files themselves, no diff

Read a diff target as a structured diff, which `GIT_EXTERNAL_DIFF=difft` gives, together with the enclosing unit of every hunk, since the finding may sit in a line the diff left alone.
Read a file target as raw files.
Either way the rest of the repository is yours to read, it is only not what you report on.
