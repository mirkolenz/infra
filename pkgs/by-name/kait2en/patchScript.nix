# Fixes up one of upstream's installed bash helpers. `patchShebangs` resolves
# `env bash` through a `HOST_PATH` that `strictDeps` leaves without bash, and a
# sleep transition provides no PATH of its own.
{ lib, runtimeShell }:
{
  path,
  runtimeInputs ? [ ],
  extraPaths ? [ ],
}:
let
  binPath = lib.concatStringsSep ":" ([ (lib.makeBinPath runtimeInputs) ] ++ extraPaths);
in
''
  substituteInPlace ${path} --replace-fail '#!/usr/bin/env bash' \
    "#!${runtimeShell}"$'\n'"export PATH=${binPath}\''${PATH:+:\$PATH}"
''
