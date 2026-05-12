{ inputs, ... }:
final: prev:
let
  inherit (prev.stdenv.hostPlatform) system;
  fromInput = input: package: inputs.${input}.packages.${system}.${package} or final.empty;
in
{
  cosmic-manager = fromInput "cosmic-manager" "cosmic-manager";
  disko = fromInput "disko" "disko";
  disko-install = fromInput "disko" "disko-install";
  mistral-vibe = fromInput "mistral-vibe" "default";
  opnix = fromInput "opnix" "default";
}
