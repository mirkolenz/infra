---
name: kait2en
description: |
  Updates the Apple T2 support, the `kait2en` packages and the `apple-t2` NixOS module, to the latest KaiT2en upstream.
  Use when the user asks to update KaiT2en, or when a kait2en package fails after a nixpkgs or kernel bump.
---

Advance the KaiT2en pin, review everything upstream changed since the last reviewed revision, and carry it into the packages and the module.
`pkgs/by-name/kait2en/README.md` holds the packaging decisions, read it first and keep it current.
Upstream rejects issues and pull requests it believes an AI wrote, so never open one.

## Layout

- `modules.nix` pins `src` for every package and mirrors the `MODULES`, `EARLY_MODULES`, and `ADD_ARGS` arrays of upstream's installer scripts.
- `upstream-check.nix` pins `reviewedSrc` and `reviewedFork`, which only move after a review.
- `review.py` next to this file lists what changed since then and advances both.
- `modules/hardware/apple-t2/` wires the packages into NixOS, and `macbook-161` is the only host using it.
- The scheduled updater skips this scope, and every package is x86_64-linux only.

## Steps

1. Bump the pin and the Cargo hashes.

   ```sh
   nix-update kait2en.modules --system x86_64-linux --version=branch \
     --subpackage=autobrightness \
     --subpackage=ave \
     --subpackage=debug \
     --subpackage=journal \
     --subpackage=power-explorer \
     --subpackage=smc-control \
     --subpackage=touchbar \
     --subpackage=touchid \
     --subpackage=zone-power
   ```

2. Run the drift check, which diffs Cargo metadata, Makefiles, and service and integration files against `reviewedSrc`.

   ```sh
   nix build .#kait2en-upstream-check
   ```

3. Review the whole range, not only the drift diff, since requirements hidden in code slip past it.

   ```sh
   .agents/skills/kait2en/review.py upstream
   ```

   Look for new native dependencies, Fedora paths such as `/usr` or `/etc` the `--replace-fail` patches must follow, new or renamed units, and new apps or scripts.
   Package a new app or record why not under "Deliberately not packaged" in the README.
   Move the `linuxPackages_<major>_<minor>` pin in `modules.nix` once upstream targets a new kernel series, as the `kernel_version_ge` cutoffs in `install-gpu-runtime-pm.sh` and the Fedora release under `auto-installer/targets` show.

4. Review what the [NixOS fork](https://github.com/LukeChannings/KaiT2en-NixOS) changed in its Nix layer since `reviewedFork`, a second view on the same upstream.

   ```sh
   .agents/skills/kait2en/review.py fork
   ```

   Look for kernel parameters, modules, units, or workarounds it added, changed, or removed, and the upstream change behind each.
   Carry over what upstream itself asks for, and drop what we took from it once it removes it.
   Its own divergences, such as patches under `patches/nixos/` or quirks in its profiles, need a reason that applies here.

5. Build every runtime package, listed by the eval below.

   ```sh
   nix eval --json .#packages.x86_64-linux --apply 'p: builtins.filter (n: builtins.match "kait2en-.*" n != null) (builtins.attrNames p)'
   nix build .#packages.x86_64-linux.kait2en-<name>...
   ```

   `<ARRAY> in <file> changed upstream` means a list in `modules.nix` must follow upstream, `the amdgpu softdep changed upstream` means `modprobeConfig` in `amdgpu.nix` must, and `the merged amdgpu patches changed upstream` means `mergedSince` must.

6. Advance `reviewedSrc` to `src` and `reviewedFork` to the fork's `main`, then rerun the drift check.

   ```sh
   .agents/skills/kait2en/review.py advance
   ```

7. Build the host, which also catches module options that moved.

   ```sh
   nix build .#nixosConfigurations.macbook-161.config.system.build.toplevel
   ```

After moving the kernel pin, or a nixpkgs bump within its series, steps 5 and 7 alone show whether the drivers and the amdgpu patches still apply.
The host runs the integrated GPU, so only step 5 builds `kait2en-amdgpu`.

## Conventions

- New packages reuse `mkService`, `mkScript`, or `mkGtkApp`, take `commonMeta`, and install the notices with `installLicenses`.
- The builds cannot catch a Fedora path left unpatched in a runtime script, so grep the installed output for `/usr` and `/etc`.

## Output

The old and new revision of upstream and of the fork, the changes in both and how each was carried over or deliberately skipped, and the builds run with their result.
