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
- `upstream-check.nix` pins `reviewedSrc`, which only moves after a review.
- `modules/hardware/apple-t2/` wires the packages into NixOS, and `macbook-161` is the only host using it.
- The scheduled updater skips this scope, and every package is x86_64-linux only.

## Steps

1. Bump the pin and the Cargo hashes.

   ```sh
   nix-update kait2en.modules --system x86_64-linux --version=branch \
     --subpackage=ave --subpackage=journal --subpackage=power-explorer \
     --subpackage=smc-control --subpackage=touchbar --subpackage=touchid
   ```

2. Run the drift check, which diffs Cargo metadata, Makefiles, and service and integration files against `reviewedSrc`.

   ```sh
   nix build .#kait2en-upstream-check
   ```

3. Review the whole range, not only the drift diff, since requirements hidden in code slip past it.

   ```sh
   gh api repos/kaiT2en/KaiT2en-Fedora/compare/<reviewedSrc.rev>...<src.rev> -q '.files[] | "\(.status)\t\(.filename)"'
   ```

   Look for new native dependencies, Fedora paths such as `/usr` or `/etc` the `--replace-fail` patches must follow, new or renamed units, and new apps or scripts.
   Package a new app or record why not under "Deliberately not packaged" in the README.

4. Build every runtime package, listed by the eval below.

   ```sh
   nix eval --json .#packages.x86_64-linux --apply 'p: builtins.filter (n: builtins.match "kait2en-.*" n != null) (builtins.attrNames p)'
   nix build .#kait2en-<name>...
   ```

   `<ARRAY> in <file> changed upstream` means a list in `modules.nix` must follow upstream, and `the amdgpu softdep changed upstream` means `modprobeConfig` in `amdgpu.nix` must.

5. Set `reviewedSrc` to the new `src.rev` and `src.hash`, then rerun the drift check.
6. Build the host, which also catches module options that moved.

   ```sh
   nix build .#nixosConfigurations.macbook-161.config.system.build.toplevel
   ```

After a nixpkgs bump moves `linuxPackages_latest`, steps 4 and 6 alone show whether the drivers and the amdgpu patches still apply.

## Conventions

- New packages reuse `mkService`, `mkScript`, or `mkGtkApp`, take `commonMeta`, and install the notices with `installLicenses`.
- The builds cannot catch a Fedora path left unpatched in a runtime script, so grep the installed output for `/usr` and `/etc`.

## Output

The old and new revision, the upstream changes and how each was carried over or deliberately skipped, and the builds run with their result.
