---
name: my-simplify
description: |
  Reviews code for reuse, simplification, efficiency, and altitude cleanups, then applies the fixes.
  Quality only, it does not hunt for bugs.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks to simplify, clean up, or refactor.
---

Improve the quality of the code and apply the fixes.
Leave correctness to the `my-review` skill.

## Scope

A commit, range, branch, or pull request is diff mode, and a path or the whole tree is file mode.
Over a whole tree, target accumulated cruft, rank by duplication and complexity, then split along the repository's own units such as a module, package, or crate.
A unit is the smallest scope a helper is shared within, so splitting finer hides duplication.
Give each unit to exactly one agent, and say which parts nobody reached.
Fix in small self-contained edits rather than one sweeping rewrite.

## Tools

These are installed.
Run a tool once and share its output when several angles read it, otherwise let the agent that needs it run it.
Run what the languages present call for, and record what was skipped.

```sh
# ripwire: the layout, so an agent knows where shared helpers live
ripwire .

# jscpd: duplication across 220 languages, but not nix, so judge nix by reading
jscpd --min-tokens 50 <scope>

# scc, lizard: complexity per file and per function
scc
lizard

# rust-code-analysis-cli: cognitive complexity and maintainability,
# for code that reads worse than its cyclomatic complexity suggests
rust-code-analysis-cli -m -O json -p <path>

# ast-grep: whether a new shape already exists elsewhere
ast-grep run --pattern '<shape>' <path>

# knip, oxlint: typescript files and exports nothing uses, and simpler idioms
knip
oxlint --type-aware --type-check

# ruff, perflint: python idioms from pyupgrade, refurb, and perflint,
# and the loop-invariant work ruff does not cover
uv run ruff check --select UP,FURB,PERF
perflint <path>

# vulture, deptry: python code nothing reaches, and dependencies nothing imports
vulture <path>
deptry .

# golangci-lint: the go linter, including the unused checker
golangci-lint run

# statix, deadnix: nix antipatterns and unused bindings
statix check
deadnix

# clippy, cargo-machete: the rust linter, and dependencies nothing imports.
# `cargo udeps` answers the same by building, so only when machete is contested
cargo clippy
cargo machete

# typos, harper-cli, lychee: spelling, grammar, and dead links
typos
harper-cli lint <file>
lychee .
```

## Angles

Cover every angle below, grouping angles that read the same material into one agent.
Skip an angle whose subject the target does not contain, and say so.

- Reuse: code that re-implements an existing helper, naming the helper.
  Every `jscpd` clone pair is a candidate, so judge which side becomes the shared one.
- Simplification: redundant or derivable state, copy-paste with slight variation, deep nesting, and dead code.
  Name the simpler form.
- Efficiency: redundant computation, repeated I/O, independent work run sequentially, and blocking work on a hot path.
  Long-lived closures keep their whole scope alive, so prefer a struct holding only the needed fields.
- Altitude: special cases layered on shared infrastructure, naming the mechanism to generalize instead.

## Output

Each finding names the file and line, states what is duplicated, wasted, or hard to maintain, and gives the better form.
Apply each fix directly.
Skip a fix that would change intended behavior, reach well outside the scope, or that you judge a false positive, and say so.
Close with what was fixed, what was skipped, and which angles did not run and why, so repeated runs stay comparable.
