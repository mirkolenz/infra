# KaiT2en

Support for Macs with an Apple T2 security chip, taken from [KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora).
Upstream ships its drivers as DKMS packages for a stock Fedora kernel, so NixOS can build them against a cached kernel.

| package           | what it is                                                      |
| ----------------- | --------------------------------------------------------------- |
| `kait2en.modules` | the out-of-tree drivers, built against `passthru.kernel`        |
| `kait2en.ucm`     | `alsa-ucm-conf` extended with the Apple T2 use case profiles    |
| `kait2en.dsp`     | PipeWire filter graphs for the internal speakers, per Mac model |
| `kait2en.ncm`     | runs feature hooks around suspend and resume                    |
| `kait2en.suspend` | reloads the Broadcom Wi-Fi and Bluetooth modules across S3      |
| `kait2en.touchid` | Touch ID bridge between the T2 sensor and stock fprintd         |
| `kait2en.journal` | `t2journal`, merging bridgeOS logs into a Linux boot            |
| `kait2en.ave`     | `t2remote`, the userspace half of the T2 audio/video engine     |

`modules.nix` pins the revision every other package takes its `src` and `version` from.
Its `passthru` exports what the NixOS module in `modules/hardware/apple-t2` needs: the kernel, the initrd modules, the blacklisted modules and the kernel parameters.
`touchid`, `journal` and `ave` talk to the T2 over its CDC-NCM link, which `bridge.nix` brings up with the network profile and sleep hooks from upstream's `t2-services/shared`.

## Licensing

Upstream's drivers under `modules/` and `t2-services/t2-ave/kernel` are GPL-2.0, everything else is GPL-3.0-or-later.
`kait2en.modules` lists both `gpl2Only` and `gpl2Plus`, since each forked driver kept the license of its kernel file.
`kait2en.journal` also vendors the Apache-2.0 `macos-unifiedlogs`.

The GPL-3.0-or-later components carry an attribution term under section 7(b), so every package installs upstream's license notices to `share/licenses/<pname>`, through `installLicenses.nix` or, for `kait2en.dsp`, the upstream Makefile.
`{ave,bridge,touchid}.nix` transliterate upstream units and carry its copyright next to the link.
`graphics.nix` only reimplements the behaviour of t2-dgpu-control, so it just links.

## Updating

Upstream is followed on `main`, since its tags mark Fedora installer releases and lag behind.
The scheduled updater skips this package.

1. Bump the pin from the repository root:

   ```shell
   nix-update kait2en.modules --system x86_64-linux --version=branch \
     --subpackage=touchid --subpackage=journal --subpackage=ave
   ```

   This evaluates the non-flake `default.nix`, since `-F` cannot locate `modules.nix` under lazy trees.
   The subpackages refresh the Rust `cargoHash` values, which is also why the pin cannot move to a file of its own through `--override-filename`.

2. Review the upstream range from the `reviewed-rev:` marker in `modules.nix` to the new `rev`:

   ```shell
   gh api repos/kaiT2en/KaiT2en-Fedora/compare/REVIEWED_REV...REV \
     -q '.files[] | "\(.status)\t\(.filename)"'
   ```

3. Build every package:

   ```shell
   nix build --no-link .#packages.x86_64-linux.kait2en-{modules,ucm,dsp,ncm,suspend,touchid,journal,ave}
   ```

   The lists in `modules.nix` mirror the arrays upstream's installer scripts build, and `mirrored` pairs each with its source.
   Only the top-level assignments of a script run, parsed out by shfmt, so `ADD_ARGS` already carries both blacklists.
   A failure reading `<ARRAY> in <file> changed upstream` means one of them moved, so update the matching list.

4. Move the marker to the new `rev`, in the same commit as whatever the review made necessary.
   Keep it short, because nix-update replaces every occurrence of the full old `rev`.

The build cannot catch:

- New upstream components outside the mirrored arrays, see below for those left out on purpose.
- Changes to the GPU runtime PM patches under `patches/runtime`, which upstream only builds for the MacBookPro15,1, MacBookPro16,1 and MacBookPro16,4.
- Renamed drivers, except the ones `touchbar.nix` patches into the tiny-dfr udev rules with `--replace-fail`.

## Deliberately not packaged

The GTK applications under `apps/` configure Fedora by writing `/etc` and calling `systemctl enable`, which NixOS does not allow.
Where their effect is worth having, the NixOS module states it instead:

- `t2-dgpu-control` is reimplemented in `graphics.nix`.
- `t2-force-click` is replaced by `trackpad.nix` setting the module parameters, and the force click is a `BTN_TASK` event on the `T2 Force Click Events` device that anything can bind.
- `t2-hybrid-gpu-control` and `t2-kernel-builder` need a patched Fedora kernel.
- `t2-fan-control` and `t2-smc-control` edit a fan curve the SMC already runs in firmware.
- `t2-cpu-control` and `t2-power-tune` set power and thermal limits that have to be measured per machine, so they are left to a deliberate decision, like the disabled `services.mbpfan`.
- `t2-power-explorer` is a diagnostic view.

Of the installer steps, `install-hardware-video-decoding.sh` is covered by the `coffee-lake` import.
`install-acpi-fixes.sh` overrides the `CpuSSDT` and `DSDT` tables, which on NixOS means committing the machine's own patched AML to the initrd, so check first whether the machine needs it:

```shell
journalctl -kb | grep -E 'AE_AML_BUFFER_LIMIT|Marking method.*_PDC'
```

Upstream rejects issues and pull requests they believe were written by an AI, so anything reported there has to be written by hand.
