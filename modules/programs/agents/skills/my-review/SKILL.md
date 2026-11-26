---
name: my-review
description: |
  Reviews code for correctness bugs plus reuse, simplification, efficiency, altitude, and convention cleanups, then reports the findings.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks to review code or a pull request.
---

Find the real bugs in the code under review, and say what breaks and how.
Review for recall, since a missed bug ships and an uncertain finding costs less than a dropped one.

## Scope

A commit, range, branch, or pull request is diff mode, and a path or the whole tree is file mode.
Without an argument, take `git diff HEAD`.
If it is empty, take `git diff @{upstream}...HEAD`, then the diff against the default branch, then `git diff HEAD~1`.
In diff mode a touched function is in scope whole, since the bug may sit in an untouched line.
Over a whole tree, rank by complexity and churn, then split along the repository's own units such as a module, package, or crate.
Give each unit to exactly one agent, and say which parts nobody reached.

## Tools

These are installed.
Run a tool once and share its output when several angles read it, otherwise let the agent that needs it run it.
Run what the languages present call for, and record what was skipped.

```sh
# git: recent intent
git log --oneline -20

# difft: structural diff, which separates a real change from reformatting
GIT_EXTERNAL_DIFF=difft git diff

# semgrep, ast-grep: rule-driven defects, and syntax shapes the rules miss
semgrep --config auto
ast-grep run --pattern '<shape>' <path>

# oxlint, knip: typescript linting, and files, exports, and dependencies nothing uses
oxlint --type-aware --type-check
knip

# ruff, ty, basedpyright, vulture: python linting, type checking, and unreachable code.
# the two type checkers disagree usefully
uv run ruff check
uv run ty check
uv run basedpyright --level error
vulture <path>

# golangci-lint, nilaway: the go linter, and nil-panic paths nothing else reports
golangci-lint run
nilaway ./...

# nixf-diagnose, statix, deadnix: nix diagnostics, antipatterns, and unused bindings.
# `nix flake check --no-build` checks that the flake evaluates without building every output
nixf-diagnose
statix check
deadnix
nix flake check --no-build

# clippy, cargo-machete: the rust linter, and dependencies nothing imports
cargo clippy
cargo machete

# shellcheck: bash and sh, it does not parse fish
shellcheck <script>

# typos, harper-cli, lychee: spelling, grammar, and dead links
typos
harper-cli lint <file>
lychee .

# scc, lizard: complexity per file and per function, which ranks a sweep
scc
lizard

# keep-sorted: the repository's own ordering rules, in lint mode since it fixes by default
keep-sorted --mode lint <files>
```

## Angles

Cover every angle below, grouping angles that read the same material into one agent.
Start all agents in one message, so that they run in parallel.
Skip an angle whose subject the target does not contain, and say so.
The same line may be flagged twice for different reasons.

- Defects: what input, state, timing, or platform makes a line wrong.
  Inverted conditions, off-by-one, null dereference, missing `await`, falsy-zero checks, wrong-variable copy-paste, and swallowed errors.
  Coercion, closure-captured loop variables, mutable default arguments, nil-map writes, injection, timezone drift, float equality, and narrowed lock scope.
  Check each tool hit in context, then keep reading for what no rule covers.
- Removed behavior: the invariant a removed line enforced, and where the new code re-establishes it.
  A guard, error path, or test with no replacement is a finding.
- Cross-file impact: whether a new precondition, return shape, exception, or ordering breaks the callers or callees.
  Wrappers such as caches, proxies, and adapters are where this hides.
- Cleanup: reuse, derivable or dead complexity, wasted work, and special-case fixes where the mechanism should generalize.
  The `my-simplify` skill goes deeper on this.
- Conventions: the code against AGENTS.md and its surroundings, naming the broken rule.

## Output

Each finding names the file and line, states the defect in one sentence, and gives the input and state that make it fail.
Label a finding `important` when the change adds or worsens it, `pre_existing` when it was there before, and `nit` when it is minor.
Rank by severity with correctness above cleanup, and merge only findings of the same defect at the same place.
Then give each finding to a separate agent that tries to disprove it.
Label a finding that survives `CONFIRMED` and one that the agent cannot settle `PLAUSIBLE`, and drop only the disproved ones.
Report the strongest findings rather than a fixed number.
Close with the angles and parts skipped and why, so repeated runs stay comparable.
If a findings-reporting tool is available, call it once instead of printing them.
