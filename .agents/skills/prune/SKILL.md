---
name: prune
description: |
  Finds the hotfixes, overrides, patches, and todos that the locked flake inputs make obsolete, then removes them.
  Use after an input update, or when the user asks which workarounds can go.
---

Drop every workaround the locked inputs no longer need, and keep the rest with the reason.
Judge against the locked sources, hydra, and upstream trackers, never against memory.

## Scope

- `pkgs/overrides/hotfixes.nix`, where each entry names the fix it waits for.
- `pkgs/overrides/ports.nix` and `determinate.nix`, where each entry says what would let it go.
- `pkgs/by-name/`, for wrapped `prev` packages, `patches`, `pythonRelaxDeps`, `doCheck = false`, and fixes noted as landed after a tag.
- `modules/` and `options/`, for todos, commented-out packages, `final.stable` pins, and links to nixpkgs, home-manager, nix-darwin, or nix issues.

Skip `pkgs/by-name/kait2en/`, which tracks its upstream through `upstream-check.nix`.

```sh
rg -n -i 'todo|fixme|broken|until|once |fixed upstream|issues/|pull/|patch|override|relax|doCheck|disabledTests|stable\.' --type nix
```

## Evidence

Linux builds from `nixpkgs-linux-unstable`, darwin from `nixpkgs`, and `final.stable` from `nixpkgs-<os>-stable`.
Check an `isLinux` or `isDarwin` entry against its input only, any other entry against both.

```sh
# sources of a locked input, also home-manager, nix-darwin, or any other
nix-flake-input <input>

# hydra history of the unpatched job, `unstable` matches the inputs above on either os
hydra-check --arch <system> --channel unstable <attr>

# state of an upstream fix
gh pr view <n> -R <owner/repo> --json state,mergedAt
gh issue view <n> -R <owner/repo> --json state,comments
```

## Rules

- A build fix or `stable` pin is obsolete once hydra builds the unpatched job on every system it covers.
- A runtime fix is obsolete once the locked source has it, so compare the version, `Cargo.lock`, or the patched lines in `src`.
- A version-gated override is obsolete once the version moved on.
- An override of an argument the package no longer takes is obsolete.
- A merged pull request counts only once it reached the locked revision.

## Verify

Hydra reports its newest eval, which can be ahead of the lock, so confirm every removed build fix against the locked output.

```sh
nix path-info --store https://cache.nixos.org $(nix eval --raw .#legacyPackages.<system>.<attr>.outPath)
deadnix pkgs modules
```

## Output

The removed entries with their evidence, a table of the kept ones with the reason, and the candidates left unchecked and why.
