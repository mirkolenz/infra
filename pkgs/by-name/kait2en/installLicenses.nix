# Ships upstream's notices the way its own packaging does, with the license of
# the component in place of the top-level one where it has its own.
# Its GPL-3.0-or-later components add terms under section 7, (b) keeps the
# author attribution and (c) asks modified versions to state they are based on
# KAIT2EN, which the README does.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/LICENSING.md
{ lib, writeText }:
let
  readme = writeText "README" ''
    This is a modified version of KAIT2EN, packaged for NixOS.
    It is based on KAIT2EN (https://github.com/kaiT2en/KaiT2en-Fedora),
    is not KAIT2EN itself, and ships none of its brand assets.
  '';
in
{ pname, src, ... }:
''
  dest=$out/share/licenses/${pname}
  license=${src}/${lib.defaultTo "." src.root}/LICENSE
  while [ ! -f "$license" ]; do
    license=$(dirname "$(dirname "$license")")/LICENSE
  done

  install -Dm444 "$license" "$dest/LICENSE"
  install -Dm444 -t "$dest" ${src}/LICENSING.md ${src}/LICENSES/*.txt
  install -Dm444 ${readme} "$dest/README"
''
