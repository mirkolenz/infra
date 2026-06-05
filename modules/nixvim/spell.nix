{
  flake.modules.nixvim.default =
    { pkgs, lib, ... }:
    let
      fileHashes = {
        "de.latin1.spl" = "sha256-iedU+cMNolKlNP6aSzTeDV/72DlnuqWccb/yb/UAw0I=";
        "de.latin1.sug" = "sha256-lT+tH0Hx0ZnUhp8IdsPm26tlNyIl+LoT7dAho0A74Fc=";
        "de.utf-8.spl" = "sha256-c8cQfqM5hWzb6SHeuSpFk5xN5uucByYdobndGfaDo9E=";
        "de.utf-8.sug" = "sha256-E9Ds+Shj2J72DNSopesqWhOg6Pm6jRxqvkerqFcUqUg=";
        "en.ascii.spl" = "sha256-zry6SJ1F2jNVlA80BYLiDONezc1E+cwWi+hz8I54JEk=";
        "en.ascii.sug" = "sha256-sNXQ7RlzX4NySO+XvMtEStcwNAsXhcj2qORFj2hyIWw=";
        "en.latin1.spl" = "sha256-Yg2e/Nec/J1jmBj7UoB+Pa5ho3yADWlKAQzVJaIWGEU=";
        "en.latin1.sug" = "sha256-5t6X5Lyz+bSq9+HrVKgbk5DVwjH0J/pL43mKJeRiKwI=";
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
