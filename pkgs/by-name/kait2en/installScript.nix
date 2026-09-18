# Installs one of upstream's bash helpers. `patchShebangs` resolves `env bash`
# through a `HOST_PATH` that `strictDeps` leaves without bash, and a sleep
# transition provides no PATH of its own.
{ lib, runtimeShell }:
{
  src,
  dest,
  runtimeInputs ? [ ],
  extraPaths ? [ ],
}:
''
  install -Dm555 ${src} ${dest}
  substituteInPlace ${dest} \
    --replace-fail '#!/usr/bin/env bash' '#!${runtimeShell}'
  wrapProgram ${dest} --prefix PATH : ${
    lib.concatStringsSep ":" ([ (lib.makeBinPath runtimeInputs) ] ++ extraPaths)
  }
''
