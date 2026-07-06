final: prev:
let
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final) inputs lib';
  fromInput = input: package: inputs.${input}.packages.${system}.${package} or prev.emptyDirectory;
in
{
  cosmic-manager = fromInput "cosmic-manager" "cosmic-manager";
  disko = fromInput "disko" "disko";
  disko-install = fromInput "disko" "disko-install";
  hermes-agent = lib'.disableHydra (fromInput "hermes-agent" "default");
  mistral-vibe = lib'.disableHydra (fromInput "mistral-vibe" "default");
  opnix = fromInput "opnix" "default";
}
