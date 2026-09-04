final: prev:
let
  inherit (prev) lib;
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final) inputs;
  fromInput = input: package: inputs.${input}.packages.${system}.${package} or null;
  dontDistribute = lib.mapNullable lib.dontDistribute;
in
{
  cosmic-manager = fromInput "cosmic-manager" "cosmic-manager";
  disko = fromInput "disko" "disko";
  disko-install = fromInput "disko" "disko-install";
  mistral-vibe = dontDistribute (fromInput "mistral-vibe" "default");
  opnix = fromInput "opnix" "default";
  vicinae = dontDistribute (fromInput "vicinae" "default");
}
