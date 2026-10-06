# KaiT2en

Support for Macs with an Apple T2 security chip, taken from [KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora).
Each package explains itself in its header, the NixOS module lives in `modules/hardware/apple-t2`.

`modules.nix` pins the revision every runtime package is built from.
The packages install upstream's systemd units, patched with `--replace-fail`, and the modules load them through `systemd.packages` and set `wantedBy`, since NixOS ignores `[Install]`.

## Licensing

Upstream's drivers are GPL-2.0, everything else is GPL-3.0-or-later with an attribution term under section 7(b).
Every package therefore installs upstream's license notices to `share/licenses/<pname>`.
`kait2en.journal` also vendors Apache-2.0 code, and `kait2en.touchbar` derives from the MIT-licensed tiny-dfr.

## Updating

Upstream is followed on `main`, the scheduled updater skips this package.

1. Bump the shared source pin and refresh the Cargo hashes:

   ```shell
   nix-update kait2en.modules --system x86_64-linux --version=branch \
     --subpackage=ave --subpackage=journal --subpackage=power-explorer \
     --subpackage=smc-control --subpackage=touchbar --subpackage=touchid
   ```

2. Run the upstream drift check, which compares standard Cargo metadata, Makefiles, service units and files under `systemd` and `integration` directories with `reviewedSrc`:

   ```shell
   nix build .#kait2en-upstream-check
   ```

   This only compares source files, it does not compile packages.
   Added, removed or changed metadata fails with a diff.
   It detects metadata changes for review, it does not infer native dependencies or validate service behavior.
   Requirements hidden in implementation code still need manual review.

3. Review the upstream range from `reviewedSrc.rev` in `upstream-check.nix` to the new `src.rev` in `modules.nix`:

   ```shell
   gh api repos/kaiT2en/KaiT2en-Fedora/compare/REVIEWED_REV...REV \
     -q '.files[] | "\(.status)\t\(.filename)"'
   ```

4. Build every runtime `kait2en-*` package.
   A failure reading `<ARRAY> in <file> changed upstream` means one of the lists in `modules.nix` has to follow upstream.

5. After reviewing, update `reviewedSrc` in `upstream-check.nix` to the new `src.rev` and `src.hash`, then rerun the drift check.

The drift check also runs through the flake's checks.
The package builds cannot catch Fedora paths left unpatched.

## Deliberately not packaged

- `t2-dgpu-control` and `t2-hybrid-gpu-control` are replaced by `custom.apple-t2.graphics.mode`.
- `t2-force-click` is replaced by `trackpad.nix`.
- `t2-fan-control`, `t2-cpu-control` and `t2-power-tune` change limits the firmware already manages.
- `t2-kernel-builder` needs a patched Fedora kernel.
- `install-acpi-fixes.sh` needs the machine's own patched AML, check `journalctl -kb | grep -E 'AE_AML_BUFFER_LIMIT|Marking method.*_PDC'` first.

Upstream rejects issues and pull requests they believe were written by an AI.
