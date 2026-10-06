# KaiT2en

Support for Macs with an Apple T2 security chip, taken from [KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora).
Each package explains itself in its header, the NixOS module lives in `modules/hardware/apple-t2`.
This file records the packaging decisions, updating is covered by the `kait2en` skill in `.agents/skills/kait2en`.

`modules.nix` pins the revision every runtime package is built from.
The packages install upstream's systemd units, patched with `--replace-fail`, and the modules load them through `systemd.packages` and set `wantedBy`, since NixOS ignores `[Install]`.

## Licensing

Upstream's drivers are GPL-2.0, everything else is GPL-3.0-or-later with an attribution term under section 7(b).
Every package therefore installs upstream's license notices to `share/licenses/<pname>`.
`kait2en.journal` also vendors Apache-2.0 code, and `kait2en.touchbar` derives from the MIT-licensed tiny-dfr.

## Deliberately not packaged

- `t2-dgpu-control` and `t2-hybrid-gpu-control` are replaced by `custom.apple-t2.graphics.mode`.
- `t2-force-click` is replaced by `trackpad.nix`.
- `t2-fan-control`, `t2-cpu-control` and `t2-power-tune` change limits the firmware already manages.
- `t2-kernel-builder` needs a patched Fedora kernel.
- `install-acpi-fixes.sh` needs the machine's own patched AML, check `journalctl -kb | grep -E 'AE_AML_BUFFER_LIMIT|Marking method.*_PDC'` first.
