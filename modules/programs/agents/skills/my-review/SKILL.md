---
name: my-review
description: |
  Reviews code for correctness bugs plus reuse, simplification, efficiency, altitude, and convention cleanups, then reports the findings.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks to review code or a pull request.
---

Find the real bugs in the code under review, and say what breaks and how.
Review for recall: a missed bug ships, so an uncertain finding costs less than a dropped one.

## Scope

The argument names the target and defaults to uncommitted changes.
A commit, a range, a branch or a pull request is diff mode, and a path or the whole tree is file mode.
In diff mode a touched function is in scope whole, since the bug may sit in an untouched line.
Over a whole tree, rank by complexity and churn first, then split it along the repository's own units, meaning a module, package or crate rather than a file, so an agent sees a unit whole and can still follow a call across it.
Give each unit to exactly one agent, and say which parts nobody reached.

## Tools

These are installed.
Decide per tool whether to run it yourself and pass the output on, or to name it in an agent's prompt and let the agent run it.
Running it once is right when several angles read the same expensive output.
Delegating is right when the output is bulky and only one angle consumes it, since it then never enters your context.
Either way, run what the languages present call for and record what was skipped.

```sh
# ripwire: orients you in a repository you do not know
ripwire .

# git: recent intent, and what actually changed
git log --oneline -20

# difft: structural diff, which separates a real change from reformatting
GIT_EXTERNAL_DIFF=difft git diff

# semgrep: rule-driven defects across languages
semgrep --config auto

# ast-grep: matches a syntax shape the rule sets miss
ast-grep run --pattern '<shape>' <path>

# oxlint: typescript and javascript
oxlint --type-aware --type-check

# knip: typescript files, exports and dependencies nothing uses
knip

# ruff, ty, basedpyright: python linting and type checking, the last two disagree usefully
uv run ruff check
uv run ty check
uv run basedpyright --level error

# vulture: python code nothing reaches
vulture <path>

# golangci-lint: the go linter, which bundles staticcheck and revive
golangci-lint run

# nilaway: go nil-panic paths nothing else reports
nilaway ./...

# nixf-diagnose, statix, deadnix: nix diagnostics, antipatterns, bindings nothing references
nixf-diagnose
statix check
deadnix

# nix: whether the flake still evaluates. building every output is not part of a review
nix flake check --no-build

# clippy, cargo-machete: the rust linter, and dependencies nothing imports
cargo clippy
cargo machete

# shellcheck: bash and sh. it does not parse fish, so read those by hand
shellcheck <script>

# typos, harper-cli: spelling and grammar in identifiers, comments and prose
typos
harper-cli lint <file>

# lychee: links that no longer resolve
lychee .

# scc, lizard: complexity per file and per function, which is how a sweep gets ranked
scc
lizard

# keep-sorted: the repository's own ordering rules. it fixes by default, so lint here
keep-sorted --mode lint <files>
```

## Angles

Cover every angle below.
How many agents that takes is yours to choose: give one agent several angles when they read the same material, since the cost is in reading it twice, not in the extra angle.
Skip an angle whose subject the target does not contain, and say which and why, so a quiet gap never reads as a clean run.
Let the same line be flagged twice for different reasons, whether by one agent or two.

- Defects in the code as written: what input, state, timing, or platform makes a line wrong, and what the rules miss.
  Inverted conditions, off-by-one, null dereference, missing `await`, falsy-zero checks, wrong-variable copy-paste, swallowed errors.
  Coercion, closure-captured loop variables, mutable default arguments, nil-map writes, injection, timezone drift, float equality, narrowed lock scope.
  Confirm each tool hit in context before reporting it, then keep reading for what no rule covers.
- Removed behavior: the invariant a deleted line enforced, and where the new code re-establishes it.
  A guard, error path, or test with no replacement is a finding.
- Cross-file impact: whether a new precondition, return shape, exception, or ordering dependency breaks the callers, and the reverse for the callees.
  Wrappers such as caches, proxies and adapters are where this hides.
- Cleanup: what the repository already has, complexity that is derivable or dead, wasted work, and fixes applied as special cases where the mechanism should generalize.
  The `my-simplify` skill goes deeper on this.
- Conventions: the code against AGENTS.md and its surroundings, naming the rule that is broken.

## Output

A finding names a file and line, states the defect in one sentence, and gives the input and state that make it fail.
Rank by severity with correctness above cleanup, and merge only the findings naming the same defect at the same place for the same reason.
Report the strongest findings rather than a fixed number, and do not pad.
Close with the angles you skipped and why, since this skill is meant to be run repeatedly and a run is only comparable to the last one if its gaps are stated.
If a findings-reporting tool is available, call it once instead of printing them.
