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
        skills.smpl = {
          description = "Review the changed code for reuse, simplification, efficiency, and altitude cleanups, then apply the fixes. Quality only, it does not hunt for bugs. Use after writing or editing code, or when the user asks to simplify, clean up, or refactor a change.";
          text = /* markdown */ ''
            # Simplify changed code

            Review only the code that has changed and apply quality refactors that preserve behavior exactly.
            This skill improves quality; it does not look for or report bugs.

            ## Scope

            - Determine the changed code from the working tree: `git diff HEAD` plus untracked files, falling back to the diff against the default branch when the change spans commits.
            - Only touch code within or directly supporting those changes; do not refactor unrelated parts of the codebase.

            ## Perspectives

            Spawn one dedicated subagent per perspective and run all four in parallel, each scoped to the changed code and reporting only findings for its own perspective:

            - Reuse: replace duplicated logic with existing helpers, or extract a shared function when the same pattern repeats.
            - Simplification: remove dead code, redundant branches, needless intermediates, and over-engineered abstractions.
            - Efficiency: drop unnecessary work, allocations, and passes when the simpler form is also faster.
            - Altitude: move logic to the right layer so each function operates at a single, consistent level of abstraction.

            Each subagent returns its proposed edits; do not let any subagent touch unrelated code.

            ## How to work

            - Spawn the four perspective subagents first, then collect, deduplicate, and reconcile their proposals before editing.
            - Apply the fixes directly; do not just list suggestions.
            - Preserve the observable behavior and public interfaces unless the change is itself about them.
            - Match the surrounding code's style, naming, and conventions.
            - Do not run formatters or auto-fixing linters unless explicitly asked.
            - After editing, briefly summarize what changed and why.
          '';
        };
      };
    };
}
