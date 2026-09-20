---
name: rvw
description: Reviews the current diff, or a PR number, branch, or path target, for correctness bugs plus reuse, simplification, efficiency, altitude, and convention cleanups, then report the findings. Use when the user asks to review code or a pull request.
---

You are reviewing for **recall** at extra-high effort: catch every real bug.
At this level, catching real bugs matters more than avoiding false positives, because a missed bug ships.
Err on the side of surfacing.

## Argument

This skill takes an optional argument naming the review target: a PR number, a branch name, or a file path.
Without an argument, review the current diff.

## Phase 0: Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1` if there is no upstream) to get the unified diff under review.
If there are uncommitted changes, or the range diff is empty, also run `git diff HEAD` and include the working-tree changes in scope, since the review often runs before the commit.
If a PR number, branch name, or file path was passed as an argument, review that target instead.
Treat this diff as the review scope.

## Phase 1: Find candidates

Five correctness angles, three cleanup angles, one altitude angle, and one conventions angle, up to 8 candidates each.
Run **10 independent finder angles** in sequence yourself, in THIS context, and do NOT spawn subagents for them.
Each surfaces **up to 8 candidate findings** with `file`, `line`, a one-line `summary`, and a concrete `failure_scenario`.
Do NOT let one angle's conclusions suppress another's: if two angles flag the same line for different reasons, record both.

### Angle A: line-by-line diff scan

Read every hunk in the diff, line by line.
Then Read the enclosing function for each hunk, since bugs in unchanged lines of a touched function are in scope (the PR re-exposes or fails to fix them).
For every line ask: what input, state, timing, or platform makes this line wrong?
Look for inverted/wrong conditions, off-by-one, null/undefined deref, missing `await`, falsy-zero checks, wrong-variable copy-paste, error swallowed in catch, unescaped regex metachars.

### Angle B: removed-behavior auditor

For every line the diff DELETES or replaces, name the invariant or behavior it enforced, then search the new code for where that invariant is re-established.
If you cannot find it, that is a candidate: a removed guard, a dropped error path, a narrowed validation, a deleted test that was covering a real case.

### Angle C: cross-file tracer

For each function the diff changes, find its callers (Grep for the symbol) and check whether the change breaks any call site: a new precondition, a changed return shape, a new exception, a timing/ordering dependency.
Also check callees: does a parallel change in the same PR make a call unsafe?

### Angle D: language-pitfall specialist

Scan for the classic pitfalls of the diff's language/framework, for example: JS falsy-zero, `==` coercion, closure-captured loop var, Python mutable default args, late-binding closures, Go nil-map write, range-var capture, SQL injection, timezone/DST drift, float equality.
Flag any instance the diff introduces.

### Angle E: wrapper/proxy correctness

When the PR adds or modifies a type that wraps another (cache, proxy, decorator, adapter), check that every method routes to the wrapped instance and not back through a registry/session/global.
For example, a caching provider holding a `delegate` field that resolves IDs via `session.get(...)` instead of `delegate.get(...)` will re-enter the cache or recurse.
Also check that the wrapper forwards all the methods the callers actually use.

### Reuse

The angles above hunt for bugs, this one and the next two hunt for cleanup in the changed code.
Flag new code that re-implements something the codebase already has.
Grep shared/utility modules and files adjacent to the change, and name the existing helper to call instead.

### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state, copy-paste with slight variation, deep nesting, dead code left behind.
Name the simpler form that does the same job.

### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O, independent operations run sequentially, blocking work added to startup or hot paths.
Also flag long-lived objects built from closures or captured environments, since they keep the entire enclosing scope alive for the object's lifetime (a memory leak when that scope holds large values), and prefer a class/struct that copies only the fields it needs.
Name the cheaper alternative.

### Altitude

Check that each change is implemented at the right depth, not as a fragile bandaid.
Special cases layered on shared infrastructure are a sign the fix is not deep enough, so prefer generalizing the underlying mechanism over adding special cases.

### Conventions (CLAUDE.md)

Find the CLAUDE.md files that govern the changed code: the user-level ~/.claude/CLAUDE.md, the repo-root CLAUDE.md, plus any CLAUDE.md or CLAUDE.local.md in a directory that is an ancestor of a changed file (a directory's CLAUDE.md only applies to files at or below it).
Read each one that exists, then check the diff for clear violations of the rules they state.
Only flag a violation when you can quote the exact rule and the exact line that breaks it, with no style preferences and no vague "spirit of the doc" inferences.
In the finding, name the CLAUDE.md path and quote the rule so the report can cite it.
If no CLAUDE.md applies, return nothing for this angle.

### Shape of cleanup candidates

Cleanup, altitude, and conventions candidates use the same `file`/`line`/`summary` shape.
In `failure_scenario`, state the concrete cost (what is duplicated, wasted, harder to maintain, or which CLAUDE.md rule is broken) instead of a crash.
Correctness bugs always outrank cleanup, altitude, and conventions findings when the output cap forces a cut.

## Phase 2: Dedup only (no verify)

Pool all candidates.
Dedup near-duplicates only, so that the same defect at the same location for the same reason keeps one entry.
Do NOT run verifiers and do NOT re-judge.
Sort by severity.
Do NOT drop on uncertainty.

## Phase 3: Sweep for gaps

Take one more pass in the same context, with no subagent, as a fresh reviewer who has the deduplicated list.
Re-read the diff and enclosing functions looking ONLY for defects not already listed.
Do not re-derive or re-confirm anything already there, the job is gaps.
Focus on what the first pass tends to miss: moved/extracted code that dropped a guard or anchor, second-tier footguns (dataclass default evaluated once, `hash()` non-determinism, lock-scope shrink, predicate methods with side effects), setup/teardown asymmetry in tests, config defaults flipped.
Surface **up to 8 additional candidates**, each naming a defect not already on the list.
If nothing new, return nothing from this phase and do not pad.

## Output

Target **at least 7 findings**.
If fewer genuine findings exist, emit what you have and do not invent any to hit the floor.

Report at most **15 findings** ranked most-severe first.
Each entry has `file`, `line`, `summary`, `short_summary` (the claim compressed to at most 60 characters, with no rationale or consequence clause), `failure_scenario`, and `category` (a short kebab-case slug for the angle that produced it: `correctness`, `simplification`, `efficiency`, `reuse`, `altitude`, `conventions`, or a more specific slug like `test-coverage` when one fits better).
If more than 15 survive, keep the 15 most severe.

If a dedicated findings-reporting tool is available, call it once with these findings, do not also print them as text, and do not create or publish an artifact of the review, because the tool call is the report.
Otherwise write the findings as a list with one line each, formatted as `file:line summary`, followed by the failure scenario.
