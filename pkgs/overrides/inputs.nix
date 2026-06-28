final: prev:
let
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final) inputs;
  fromInput = input: package: inputs.${input}.packages.${system}.${package} or prev.emptyDirectory;
in
{
  cosmic-manager = fromInput "cosmic-manager" "cosmic-manager";
  disko = fromInput "disko" "disko";
  disko-install = fromInput "disko" "disko-install";
  herdr = fromInput "herdr" "default";
  hermes-agent = fromInput "hermes-agent" "default";
  mistral-vibe = fromInput "mistral-vibe" "default";
  opnix = fromInput "opnix" "default";
}
