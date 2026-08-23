{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.agents = {
        enable = true;
        instructions.body = /* markdown */ ''
          ## General

          - Always find the most simple, elegant, robust, reliable, and efficient solution to a problem and try to minimize the amount of code.
          - Always follow best practices and never introduce unnecessary complexity, hacky workarounds, or ugly shortcuts that may cause technical debt or maintenance issues in the future.
          - Identify shared patterns and abstractions between different parts of the code and refactor them into reusable functions to increase consistency and reduce duplication.
          - Always prefer breaking changes with clean interfaces over backwards compatibility layers or migration paths (unless explicitly asked otherwise).
          - Only generate the minimum amount of test cases needed to cover the core functionality of the code, not exhaustive test suites.
          - Only add important comments when generating code and keep it focused on non-trivial information or special cases one needs to document for future use.
          - Always pick modern solutions over legacy ones and don't care about compatibility to old hardware or software.
          - Always fix pre-existing errors and issues in the code and do not triage whether they were introduced by you.
          - Do not run formatters or auto-fixing linters automatically, only when explicitly needed.
          - In plain text files, write exactly one sentence per line: txt, md, tex, typ, rst, ...
          - Don't add prefixes such as `uvx` or `npx` to commands in backticks in these instructions, use them verbatim.
          - Read-only git operations are allowed, but never use writing git operations such as `git commit` or `git push` and leave them to the user.
          - Use dependency constraints with only the first significant version number, e.g. ^1 for 1.2.3 and ^0.1 for 0.1.2, relying on lockfiles for exact versions.
          - Don't use en-dashes, em-dashes, semicolons, or other special characters when generating text, instead use commas and periods to separate clauses and sentences.
          - Only add the minimum amount of comments needed to explain non-trivial information or special cases and avoid long-form prose comments.
          - In source code files, keep blocks such as if/while/for/try/match/return separated by blank lines from the surrounding code to improve readability.
          - When wrapping comments to fit within a certain line width, break lines at periods or commas to avoid breaking up clauses and sentences.
          - Exec `gh` to interact with GitHub, not `curl` or a built-in web fetch tool.
          - I use `fish` as my login shell, not `bash` or `zsh`, so make sure to use the correct syntax when running shell commands.

          ## Python

          - Exec `uv run` to execute Python scripts and files, not `python` or `python3`.
          - Exec `uv run ruff check` for linting Python, not `flake8` or `pylint`.
          - Exec `uv run ty check` AND `uv run basedpyright --level error` for type checking Python, not `mypy` or `pyright`.
          - Use a src-based layout for Python projects.
          - Add type annotations to Python functions and classes.
          - Add `__all__` to public modules to control what is exported.
          - Create tests using `pytest` and place them in a `tests/` directory.
          - Add docstrings to all public functions and classes.
          - Add doctests to functions and classes where appropriate.
          - Use the Google style for docstrings.
          - Never use `global` or `nonlocal` variables.
          - Prefer dataclasses over regular classes for data structures.
          - Always use `slots=True` for dataclasses and set `frozen=True` when possible.
          - Prefer `__post_init__` over `__init__` to customize dataclass initialization.
          - Always use types from `collections.abc` for annotating function parameters.
          - Prefer `pathlib` over `os` for file system operations.
          - Avoid stringified/quoted types and the `if TYPE_CHECKING` block to handle import issues, restructure the code instead to achieve proper static typing.
          - Always use the latest syntax/features of the Python version specified in pyproject.toml and never care about compatibility to older versions.

          ## Node.js

          - Use TypeScript, not JavaScript.
          - Use ES modules (import/export) syntax, not CommonJS (require).
          - Use the command `shadcn` for shadcn/ui, not `npx shadcn`.
          - Exec `npm run build` to build projects, not `npm run dev` or `npm run start`.
          - Exec `oxlint --type-aware --type-check` without npx for linting JavaScript/TypeScript, not `tsc`, `eslint` or `biome`.
          - When working with shadcn/ui, never modify the generated components directly.
          - For imports use absolute paths with the `@/` prefix, not relative paths.

          ## Nix

          - Use flakes to manage Nix projects, not channels.
          - Use flake-parts to structure flake.nix files.
          - Exec `nix-flake-input <name>` to obtain the store path of an input `<name>` such as `nixpkgs` from the current repo.
          - After creating new files, you must add them to the git index to make them visible for nix evaluations.
          - Never run plain find/grep commands in `/` or `/nix/store`.
          - Avoid nested let ... in bindings and favor top-level variables when possible.

          ## LaTeX

          - Exec `latexmk` to compile documents.
          - Use `cref` for cross-referencing, not `ref`.

          ## Typst

          - Exec `typst compile` to make sure the document is free of errors and warnings after making changes.
        '';
        # Claude Code built-in prompts, reflowed to one sentence per line.
        # To refresh after an upgrade, ask Claude to re-extract them from its own
        # bundle using the anchors below, then diff against the text here.
        skills.smpl = {
          # /simplify. Anchor: `4 cleanup agents in parallel`.
          description = "Review the changed code for reuse, simplification, efficiency, and altitude cleanups, then apply the fixes. Quality only, it does not hunt for bugs. Use after writing or editing code, or when the user asks to simplify, clean up, or refactor a change.";
          text = /* markdown */ ''
            You are improving the quality of the changed code, not hunting for bugs.
            Review it for reuse, simplification, efficiency, and altitude issues, then fix what you find.
            Do not look for correctness bugs, that is what the `rvw` skill is for.

            ## Argument

            This skill takes an optional argument naming the review target: a PR number, a branch name, or a file path.
            Without an argument, review the current diff.

            ## Phase 0: Gather the diff

            Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1` if there is no upstream) to get the unified diff under review.
            If there are uncommitted changes, or the range diff is empty, also run `git diff HEAD` and include the working-tree changes in scope, since the review often runs before the commit.
            If a PR number, branch name, or file path was passed as an argument, review that target instead.
            Treat this diff as the review scope.

            ## Phase 1: Review (4 cleanup agents in parallel)

            Launch **4 independent review agents**, all in a single message so they run concurrently.
            Pass each agent the diff and one of the four angles below.
            Each returns its findings with `file`, `line`, a one-line `summary`, and the concrete cost (what is duplicated, wasted, or harder to maintain).

            ### Reuse

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

            ## Phase 2: Apply the fixes

            Wait for all four agents to complete, dedup findings that point at the same line or mechanism, and fix each remaining one directly.
            Skip any finding whose fix would change intended behavior, require changes well outside the reviewed diff, or that you judge to be a false positive, and note the skip rather than arguing with it.
            Finish with a brief summary of what was fixed and what was skipped, or confirm the code was already clean.
          '';
        };
        skills.rvw = {
          # /code-review, xhigh effort on Opus 5. Anchor: `10 inline angles`.
          description = "Review the current diff, or a PR number, branch, or path target, for correctness bugs plus reuse, simplification, efficiency, altitude, and convention cleanups, then report the findings. Use before shipping a change, or when the user asks to review code or a pull request.";
          text = /* markdown */ ''
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
          '';
        };
      };
    };
}
