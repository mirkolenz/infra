{
  lib,
  haskell,
  haskellPackages,
  fetchgit,
  fetchFromGitHub,
  nix-update-script,
}:
# upstream's flake builds both packages with callCabal2nix, which is
# import-from-derivation and this repo evaluates with that turned off, so the two
# argument sets cabal2nix would have generated are spelled out instead
let
  # not in nixpkgs, and only ever used to colour recht's output
  blessings = haskellPackages.callPackage (
    {
      mkDerivation,
      base,
      text,
    }:
    mkDerivation {
      pname = "blessings";
      version = "2.2.0";

      src = fetchgit {
        url = "https://cgit.krebsco.de/blessings";
        rev = "d94712a015636efe7ec79bc0a2eec6739d0be779";
        hash = "sha256-YVIGRG+/ey4nFEZl1ZPHj7Hx/Of3rsUGnkLK4V4zZd0=";
      };

      libraryHaskellDepends = [
        base
        text
      ];
      doCheck = false;

      homepage = "https://cgit.krebsco.de/blessings";
      description = "Terminal formatting for Haskell";
      license = lib.licenses.mit;
    }
  ) { };

  recht = haskellPackages.callPackage (
    {
      mkDerivation,
      base,
      async,
      binary,
      bytestring,
      data-default,
      directory,
      filepath,
      megaparsec,
      optparse-applicative,
      pandoc,
      random,
      safe,
      scalpel,
      regex-tdfa,
      text,
      time,
    }:
    mkDerivation rec {
      pname = "recht";
      version = "0.7.1";

      src = fetchFromGitHub {
        owner = "kmein";
        repo = "recht";
        tag = "v${version}";
        hash = "sha256-lvD5ePoswnArhmQVJOHw/S28C8XgbjkcodhPS4hMvYw=";
      };

      isExecutable = true;

      # cabal bakes a `Paths_pandoc_types` data directory into the binary that nothing
      # reads at runtime, and the reference alone pulls in every haskell `doc` output
      # behind it, which is four gigabytes of haddock
      postInstall = ''
        remove-references-to -t ${haskellPackages.pandoc-types} "$out/bin/recht"
      '';

      executableHaskellDepends = [
        base
        blessings
        async
        binary
        bytestring
        data-default
        directory
        filepath
        megaparsec
        optparse-applicative
        pandoc
        random
        safe
        scalpel
        regex-tdfa
        text
        time
      ];

      passthru = {
        updateScript = nix-update-script { };
        vendored = {
          inherit blessings;
        };
      };

      homepage = "https://github.com/kmein/recht";
      description = "Reads German federal legislation from gesetze-im-internet.de on the command line";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ mirkolenz ];
      mainProgram = "recht";
    }
  ) { };
in
# pandoc is a library dependency, so the unstripped closure drags in a full haskell
# toolchain, while only the executable is wanted here
haskell.lib.compose.justStaticExecutables recht
