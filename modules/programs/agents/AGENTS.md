## General

- Always find the most simple, elegant, robust, reliable, and efficient solution to a problem and try to minimize the amount of code.
- Always follow best practices and never introduce unnecessary complexity, hacky workarounds, or ugly shortcuts that may cause technical debt or maintenance issues in the future.
- Identify shared patterns and abstractions between different parts of the code and refactor them into reusable functions to increase consistency and reduce duplication.
- Always prefer breaking changes with clean interfaces over backwards compatibility layers or migration paths (unless explicitly asked otherwise).
- Always pick modern solutions over legacy ones and never care about compatibility to old hardware or software.
- Always fix pre-existing errors and issues in the code and do not triage whether they were introduced by you.
- Never use en-dashes, em-dashes, semicolons, or other special characters when generating text, instead use commas and periods to separate clauses and sentences.
- Never create, update, or delete an AGENTS.md file, they are maintained solely by humans.

## Shell

- Never add prefixes such as `uvx` or `npx` to commands in backticks in these instructions, use them verbatim.
- I use `fish` as my login shell, not `bash` or `zsh`, make sure to use the correct syntax when running shell commands.

## Git

- Read-only operations are always allowed.
- Write operations such as `git commit` need explicit user permission.
- Remove operations such as `git commit` are always forbidden.
- Exec `gh` to interact with GitHub, not `curl` or a built-in web fetch tool.

## Source Code Files

- Keep blocks such as if/while/for/try/match/return separated by blank lines from the surrounding code to improve readability.
- When writing plain text, use one newline to separate sentences and two newlines to separate paragraphs: txt, md, tex, typ, rst, ...
- Never run formatters or auto-fixing linters automatically, only when explicitly needed.

## Dependencies

- Use dependency constraints with only the first significant version number: ^1 for 1.2.3 and ^0.1 for 0.1.2
- Rely on lockfiles for exact versions.
- Never install, update, or remove dependencies without user consent.

## Tests

- Only generate the minimum amount of test cases needed to cover the core functionality of the code.
- Never create not exhaustive test suites.

## Comments

- Only add the minimum amount of comments needed to explain non-trivial information or special cases, never add long-form prose text.
- When wrapping comments to fit within a certain line width, break lines at periods or commas to avoid breaking up clauses and sentences.

## Typing

- Always use proper types so that static linters can analyze the code.
- Avoid casting to overly general types such as unknown, any, object, ...
- Prefer generics over loose types if the language supports that.

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
- After creating new files, add them to the git index to make them visible for nix evaluations.
- Never run plain find/grep commands in `/` or `/nix/store`.
- Avoid nested let ... in bindings and favor top-level variables when possible.

## LaTeX

- Exec `latexmk` to compile documents.
- Use `cref` for cross-referencing, not `ref`.

## Typst

- Exec `typst compile` to make sure the document is free of errors and warnings after making changes.
