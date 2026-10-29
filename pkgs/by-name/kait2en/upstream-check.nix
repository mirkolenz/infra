{
  lib,
  fetchFromGitHub,
  runCommand,
  kait2en,
}:
runCommand "kait2en-upstream-check"
  {
    # Kept outside modules.nix so nix-update cannot advance the reviewed pin.
    reviewedSrc = fetchFromGitHub {
      inherit (kait2en.modules.src) owner repo;
      rev = "be7f136c0f9b2bf9811d88d6fd1abdc126c977d3";
      hash = "sha256-rvQqbMpZ1K5n0bWLnUGNouyUpaqCv2PGJ21CPoPtXUk=";
    };
    inherit (kait2en.modules) src;
    # The last commit reviewed of the NixOS fork packaging the same upstream.
    # https://github.com/LukeChannings/KaiT2en-NixOS
    passthru.reviewedFork = "3811916ee49ca0d26eff614149321cb7b81ba4b2";
    meta = {
      description = "Detect changes to reviewed KaiT2en build and integration metadata";
      platforms = lib.platforms.unix;
      # the diff is the same on every system, so CI runs it once
      hydraPlatforms = [ "x86_64-linux" ];
    };
  }
  ''
    metadata() {
      mkdir "$2"

      find "$1" ! -type d \( \
        -name Cargo.toml -o -name Cargo.lock -o -name build.rs -o \
        -name Makefile -o -name makefile -o -name GNUmakefile -o \
        -name '*.service' -o -path '*/systemd/*' -o -path '*/integration/*' \
      \) -printf '%P\0' | tar -C "$1" --null -T - -cf - | tar -xf - -C "$2"
    }

    metadata "$reviewedSrc" reviewed
    metadata "$src" current

    if ! diff --no-dereference -ru reviewed current; then
      echo "Upstream build or integration metadata changed, review it before advancing reviewedSrc in upstream-check.nix." >&2
      exit 1
    fi

    touch "$out"
  ''
