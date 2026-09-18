# KaiT2en

Support for Macs with an Apple T2 security chip, taken from
[KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora).
Upstream ships its drivers as DKMS packages against a stock Fedora kernel rather
than as a kernel patch set, which is why NixOS can run them on a cached kernel.

| package           | what it is                                                            |
| ----------------- | --------------------------------------------------------------------- |
| `kait2en.modules` | the nine out-of-tree driver packages, built against `passthru.kernel` |
| `kait2en.ucm`     | `alsa-ucm-conf` extended with the Apple T2 use case profiles          |
| `kait2en.dsp`     | PipeWire filter graphs for the internal speakers, per Mac model       |
| `kait2en.ncm`     | suspend and resume helper for the T2's internal bridge link           |
| `kait2en.suspend` | reloads the Broadcom Wi-Fi and Bluetooth modules across S3            |
| `kait2en.touchid` | Touch ID bridge between the T2 sensor and stock fprintd               |
| `kait2en.journal` | `t2journal`, merging bridgeOS logs into a Linux boot                  |
| `kait2en.ave`     | `t2remote`, the userspace half of the T2 audio/video engine           |

The last four talk to the T2 over its internal CDC-NCM link, which
`modules/hardware/apple-t2/bridge.nix` brings up.

`ncm` and `suspend` are upstream bash helpers rather than builds, and share
`mkScript.nix`.
`installScript.nix` holds the three steps that install one, since the sleep hook
`ave` ships needs them too without being a `mkScript` build.
`commonMeta.nix` carries the `meta` fields every package in the scope shares.

`modules.nix` holds the single revision every package is built from, and the
others take `src` and `version` back off it.
It also declares, and exports through `passthru`, everything the NixOS module
under `modules/hardware/apple-t2` needs: the kernel to build against, the
modules to load from the initrd, the in-tree modules to blacklist and the kernel
command line.

## Licensing

Upstream splits at the kernel boundary: the drivers under `modules/` and
`t2-services/t2-ave/kernel` are GPL-2.0, and everything else is
GPL-3.0-or-later.
`kait2en.modules` is the only package on the kernel side of that line, and its
`meta.license` lists both `gpl2Only` and `gpl2Plus` because the drivers forked
out of the kernel kept the license of the file they came from.
`kait2en.journal` additionally vendors `macos-unifiedlogs`, which is Apache-2.0.

The GPL-3.0-or-later components carry an attribution term under section 7(b),
so every package installs upstream's `LICENSE`, `LICENSING.md` and
`LICENSES/GPL-3.0-or-later.txt` under `share/licenses/<pname>` through
`installLicenses.nix`, the way upstream's own RPM, Debian and Makefile packaging
does.
`kait2en.dsp` gets them from the upstream Makefile instead, along with the
per-model README that carries each profile's copyright.

The NixOS module transliterates several upstream units and configuration files
rather than installing them, because they name Fedora paths.
`modules/hardware/apple-t2/{ave,bridge,touchid}.nix` carry the upstream
copyright and license next to the link, since what they reproduce is upstream's
expression and not just its effect.
`graphics.nix` only links, because it reimplements the behaviour of upstream's
t2-dgpu-control helper without taking its code.

## Updating

```shell
nix run .# -- update-pkgs -p kait2en-modules
```

This rewrites `version`, `rev` and `hash` in `modules.nix`, which moves every
package at once, and runs from CI twice a day.

The three Rust packages are reached through `nix-update --subpackage`. This is
why the pin cannot live in a file of its own behind `--override-filename`, which
nix-update would apply to the subpackages as well and write their hashes into
the wrong file.

Upstream is followed on `main` rather than on a tag: its tags mark Fedora
installer releases, lag by weeks, and the most recent one predates the module
layout packaged here.

Since a bump can cross hundreds of upstream commits, review one before
rebuilding by diffing the two revisions:

```shell
git log -p -2 -- pkgs/by-name/kait2en/modules.nix
# https://github.com/kaiT2en/KaiT2en-Fedora/compare/OLD_REV...NEW_REV
```

The four lists in `modules.nix` mirror arrays in upstream's installer scripts,
and the `mirrored` list there pairs each one with its source. A build that fails
with `<ARRAY> in <file> changed upstream` means one of them moved: read the diff,
read the surrounding script for the reason, and update the matching list.
Nothing else has to be reviewed routinely.

## What the check cannot catch

- New components outside the four arrays, such as the daemons under
  `t2-services` or the GTK applications under `apps`.
- `initcallBlacklist`, which has no upstream counterpart: it names the built-in
  symbols a blacklist cannot reach, so a nixpkgs kernel config turning one of
  those from `=y` into `=m` makes it stale.
- Kernel arguments upstream applies conditionally, currently `amdgpu.aspm=1`
  (set in `modules/hardware/apple-t2/default.nix`) and the GPU runtime PM patch
  set under `patches/runtime`, which upstream only builds for MacBookPro15,1.
- Layout changes in the UCM, DSP or t2-services trees, which surface as a build
  failure in the package that reads them instead.
- Renamed drivers, except in `tiny-dfr`, which finds the Touch Bar by driver
  name: `modules/hardware/apple-t2/touchbar.nix` adds `t2bdrm` and
  `t2tb_backlight` to its udev rules with `--replace-fail`, so a rename on
  either side fails that build instead.

Upstream rejects issues and pull requests they believe were written by an AI, so
anything reported there has to be written by hand.
