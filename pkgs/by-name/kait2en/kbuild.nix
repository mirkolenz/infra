# Runs a Kbuild target for each module directory of `dirs` against the pinned
# kernel, with `kernelModuleMakeFlags` as `makeFlags`. Those strip the modules
# on install and sign them through `cmd_sign`, as for the in-tree ones,
# and `updates` is where DKMS puts them,
# which depmod prefers over the in-tree ones.
{ lib, kait2en }:
target: dirs:
let
  inherit (kait2en.modules) kernel;
in
lib.concatMapStrings (dir: ''
  make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
    -j"$NIX_BUILD_CORES" "''${makeFlags[@]}" \
    M="${dir}" INSTALL_MOD_PATH="$out" INSTALL_MOD_DIR=updates \
    ${target}
'') dirs
