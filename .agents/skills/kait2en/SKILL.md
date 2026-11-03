---
name: kait2en
description: |
  Updates the Apple T2 support, the `kait2en` packages and the `apple-t2` NixOS module, to the latest KaiT2en upstream.
  Use when the user asks to update KaiT2en, or when a kait2en package fails after a nixpkgs or kernel bump.
---

Review everything KaiT2en upstream changed since the last reviewed revision, carry it into the packages and the module, and update the packages whose files changed.
`pkgs/by-name/kait2en/README.md` holds the packaging decisions, read it first and keep it current.
Upstream rejects issues and pull requests it believes an AI wrote, so never open one.

## Layout

- Every package pins its own sparse checkout of upstream through `fetchSource`, holding only the files it builds from, so an upstream commit rebuilds only the packages whose files it touched.
- `modules.nix` builds the kernel drivers and mirrors the `MODULES`, `EARLY_MODULES`, and `ADD_ARGS` arrays of upstream's installer scripts.
- `reviewed.json` pins the upstream and fork revisions last reviewed, which only move after a review.
- `upstream-check.nix` fails until every package's files match the reviewed upstream revision.
- `review.py` next to this file lists what changed since then, advances both, and updates the packages.
- `modules/hardware/apple-t2/` wires the packages into NixOS, and `macbook-161` is the only host using it.
- The scheduled updater skips this scope, and every package is x86_64-linux only.

## Steps

1. Review the whole range upstream changed since its reviewed revision.

   ```sh
   .agents/skills/kait2en/review.py upstream
   ```

   Look for new native dependencies, Fedora paths such as `/usr` or `/etc` the `--replace-fail` patches must follow, new or renamed units, and new apps or scripts.
   Package a new app or record why not under "Deliberately not packaged" in the README.
   Extend a package's `paths` when it starts building from a file outside its `root`.
   Move the `linuxPackages_<major>_<minor>` pin in `modules.nix` once upstream targets a new kernel series, as the `kernel_version_ge` cutoffs in `install-gpu-runtime-pm.sh` and the Fedora release under `auto-installer/targets` show.

2. Review what the [NixOS fork](https://github.com/LukeChannings/KaiT2en-NixOS) changed in its Nix layer since its reviewed revision, a second view on the same upstream.

   ```sh
   .agents/skills/kait2en/review.py fork
   ```

   Look for kernel parameters, modules, units, or workarounds it added, changed, or removed, and the upstream change behind each.
   Carry over what upstream itself asks for, and drop what we took from it once it removes it.
   Its own divergences, such as patches under `patches/nixos/` or quirks in its profiles, need a reason that applies here.

3. Advance both reviewed revisions in `reviewed.json` to the `main` branches.

   ```sh
   .agents/skills/kait2en/review.py advance
   ```

4. Run `nix-update --version=branch` for every package whose files changed, which also refreshes its Cargo hash, then run the check.

   ```sh
   .agents/skills/kait2en/review.py update
   nix build .#kait2en-upstream-check
   ```

   nix-update moves to the newest commit, so a failing check after a commit landed in between means reviewing that commit too.

5. Build every runtime package, listed by the eval below.

   ```sh
   nix eval --json .#packages.x86_64-linux --apply 'p: builtins.filter (n: builtins.match "kait2en-.*" n != null) (builtins.attrNames p)'
   nix build .#packages.x86_64-linux.kait2en-<name>...
   ```

   `<ARRAY> in <file> changed upstream` means a list in `modules.nix` must follow upstream, `the amdgpu softdep changed upstream` means `modprobeConfig` in `amdgpu.nix` must, and `the merged amdgpu patches changed upstream` means `mergedSince` must.

6. Build the host, which also catches module options that moved.

   ```sh
   nix build .#nixosConfigurations.macbook-161.config.system.build.toplevel
   ```

After moving the kernel pin, or a nixpkgs bump within its series, steps 5 and 6 alone show whether the drivers and the amdgpu patches still apply.

## Conventions

- New packages fetch their source with `fetchSource`, reuse `mkService`, `mkScript`, or `mkGtkApp`, take `commonMeta`, and install the notices with `installLicenses`.
- A source keeps its old store path when only its `root` or `paths` change, so refresh its hash with `nix-update kait2en.<name> --system x86_64-linux --version=skip`.
- A program calling other tools gets them through the `runtimeInputs` wrapper of `mkService`, not the `path` of its NixOS unit.
- The builds cannot catch a Fedora path left unpatched in a runtime script, so grep the installed output for `/usr` and `/etc`.

## Output

The old and new revision of upstream and of the fork, the changes in both and how each was carried over or deliberately skipped, and the builds run with their result.
