{
  flake.modules.nixvim.default =
    { pkgs, lib, ... }:
    let
      # Neovim always runs with encoding=utf-8, so it never reads the latin1 and ascii variants.
      fileHashes = {
        "de.utf-8.spl" = "sha256-c8cQfqM5hWzb6SHeuSpFk5xN5uucByYdobndGfaDo9E=";
        "de.utf-8.sug" = "sha256-E9Ds+Shj2J72DNSopesqWhOg6Pm6jRxqvkerqFcUqUg=";
        "en.utf-8.spl" = "sha256-/sq9yUm2o50ywImfolReqyXmPy7QozxK0VEUJjhNMHA=";
        "en.utf-8.sug" = "sha256-W25eYWVYLS/Xob+kH7zoJCxyR2IixV0XwqorqTPJMuw=";
      };
    in
    {
      extraFiles = lib.mapAttrs' (name: hash: {
        name = "spell/${name}";
        value.source = pkgs.fetchurl {
          url = "https://ftp.nluug.nl/vim/runtime/spell/${name}";
          inherit hash;
        };
      }) fileHashes;
    };
}
