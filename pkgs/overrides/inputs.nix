final: prev:
let
  inherit (prev) lib;
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final) inputs;
  fromInput = input: package: inputs.${input}.packages.${system}.${package} or prev.emptyDirectory;
in
{
  cosmic-manager = fromInput "cosmic-manager" "cosmic-manager";
  disko = fromInput "disko" "disko";
  disko-install = fromInput "disko" "disko-install";
  hermes-agent = lib.dontDistribute (fromInput "hermes-agent" "default");
  mistral-vibe = lib.dontDistribute (fromInput "mistral-vibe" "default");
  opnix = fromInput "opnix" "default";
  vicinae = lib.dontDistribute (fromInput "vicinae" "default");
}
