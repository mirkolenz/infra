{ ... }:
{
  programs.agents = {
    enable = true;
    instructions = /* markdown */ ''
      ## General

      - Always find the most simple, elegant, robust, reliable, and efficient solution to a problem and try to minimize the amount of code.
      - Always follow best practices and never introduce unnecessary complexity, hacky workarounds, or ugly shortcuts that may cause technical debt or maintenance issues in the future.
      - Identify shared patterns and abstractions between different parts of the code and refactor them into reusable functions to increase consistency and reduce duplication.
      - Always prefer breaking changes with clean interfaces over backwards compatibility layers or migration paths (unless explicitly asked otherwise).
      - Only generate the minimum amount of test cases needed to cover the core functionality of the code, not exhaustive test suites.
      - Only add important comments when generating code and keep it focused on non-trivial information or special cases one needs to document for future use.
      - Always pick modern solutions over legacy ones and don't care about compatibility to old hardware or software.
      - Do not run formatters or linters automatically, only when explicitly needed.
      - In plain text files, write exactly one sentence per line: txt, md, tex, typ, rst, ...
      - Don't add prefixes such as `uvx` or `npx` to commands in backticks in these instructions, use them verbatim.
      - Read-only git operations are allowed, but never use writing git operations such as `git commit` or `git push` and leave them to the user.

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
      - Never use globals in Python.
      - Prefer dataclasses over regular classes for data structures.
      - Always use `slots=True` for dataclasses and set `frozen=True` when possible.
      - Prefer `__post_init__` over `__init__` to customize dataclass initialization.
      - Always use types from `collections.abc` for annotating function parameters.
      - Prefer `pathlib` over `os` for file system operations.

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
      - Exec `nix flake prefetch nixpkgs --json | jq -r .storePath` to obtain the store path of the latest nixpkgs from the system flake registry.
      - Exec `nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.<name>.outPath'` to obtain the store path of an input from the current repo where `<name>` can be any input such as `nixpkgs`.
      - Never run plain find/grep commands in `/` or `/nix/store`.

      ## LaTeX

      - Exec `latexmk` to compile documents.
      - Use `cref` for cross-referencing, not `ref`.

      ## Typst

      - Exec `typst compile` to make sure the document is free of errors and warnings after making changes.
    '';
  };
}
