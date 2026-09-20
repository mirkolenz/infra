---
name: smpl
description: |
  Reviews code for reuse, simplification, efficiency, and altitude cleanups, then applies the fixes.
  Quality only, it does not hunt for bugs.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks to simplify, clean up, or refactor.
---

Improve the quality of the code and apply the fixes.
Correctness is what the `rvw` skill is for, so leave it alone here.

## Target

Read [references/target.md](references/target.md) first.
It maps the argument to the target, defaulting to uncommitted changes, and says whether to work from a structured diff or from raw files.

## Scope

Over a whole tree the goal is accumulated cruft rather than what a change just introduced, so rank by duplication and complexity first, then split it along the repository's own units, meaning a module, package or crate rather than a file.
A unit is the smallest thing a helper can be shared within, so splitting finer than that hides the duplication the sweep is looking for.
Give each unit to exactly one agent, and say which parts nobody reached.
Fix in small self-contained edits rather than one sweeping rewrite.

## Tools

These are installed.
Decide per tool whether to run it yourself and pass the output on, or to name it in an agent's prompt and let the agent run it.
Running it once is right when several angles read the same expensive output.
Delegating is right when the output is bulky and only one angle consumes it, since it then never enters your context.
Either way, run what the languages present call for and record what was skipped.

```sh
# ripwire: the layout, so an agent knows where the shared helpers already live
ripwire .

# jscpd: duplication, which is what turns a reuse candidate into a measurement.
# covers 220 languages but has no nix tokenizer, so judge nix duplication by reading
jscpd --min-tokens 50 <scope>

# scc, lizard: complexity per file and per function, so effort goes where it pays
scc
lizard

# rust-code-analysis-cli: cognitive complexity, halstead metrics, maintainability index.
# the better signal when cyclomatic complexity looks fine but the code still does not read that way
rust-code-analysis-cli -m -O json -p <path>

# ast-grep: whether a shape the code introduces already exists elsewhere
ast-grep run --pattern '<shape>' <path>

# knip, oxlint: typescript files and exports nothing uses, and simpler idioms
knip
oxlint --type-aware --type-check

# ruff: python idioms. these rule sets are ports of pyupgrade, refurb and perflint
uv run ruff check --select UP,FURB,PERF

# perflint: the loop-invariant work ruff's PERF does not cover
perflint <path>

# vulture, deptry: python code nothing reaches, and dependencies nothing imports
vulture <path>
deptry .

# golangci-lint: the go linter, which bundles revive and the staticcheck unused checker
golangci-lint run

# statix, deadnix: nix antipatterns and bindings nothing references
statix check
deadnix

# clippy, cargo-machete: the rust linter, and dependencies read straight from the sources
cargo clippy
cargo machete

# cargo-udeps: the same question answered by building, so only when machete is contested
cargo udeps

# typos, harper-cli: spelling and grammar in comments and docs
typos
harper-cli lint <file>

# lychee: links that no longer resolve
lychee .
```

## Angles

Cover every angle below.
How many agents that takes is yours to choose: give one agent several angles when they read the same material, since the cost is in reading it twice, not in the extra angle.
Skip an angle whose subject the target does not contain, and say which and why, so a quiet gap never reads as a clean run.

- Reuse: code that re-implements something the repository already has, naming the existing helper to call instead.
  Every `jscpd` clone pair is a candidate, so judge which side should become the shared one.
- Simplification: redundant or derivable state, copy-paste with slight variation, deep nesting, dead code left behind.
  Name the simpler form that does the same job.
- Efficiency: redundant computation, repeated I/O, independent work run sequentially, blocking work on a hot path.
  Long-lived objects built from closures keep the whole enclosing scope alive, so prefer a struct holding the fields it needs.
- Altitude: fixes applied as bandaids.
  Special cases layered on shared infrastructure mean the change is too shallow, so name the mechanism to generalize instead.

## Output

A finding names a file and line, states what is duplicated, wasted, or harder to maintain, and gives the better form.
Apply each fix directly.
Skip a fix that would change intended behavior, reach well outside the scope, or that you judge a false positive, and say so rather than arguing with it.
Close with what was fixed, what was skipped, and which angles did not run and why, since this skill is meant to be run repeatedly and a run is only comparable to the last one if its gaps are stated.
