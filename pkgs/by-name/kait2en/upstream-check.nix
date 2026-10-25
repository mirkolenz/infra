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
      rev = "64d952b9758f9cce68265fb24fab60ca8ae95f17";
      hash = "sha256-OrxgIpmGXT/YAtv2pRo6tISpXsye9FweYlIJmEtu5Ls=";
    };
    inherit (kait2en.modules) src;
    # The last commit reviewed of the NixOS fork packaging the same upstream.
    # https://github.com/LukeChannings/KaiT2en-NixOS
    passthru.reviewedFork = "7d00c8556d9e799d266e5b62230dec9cb33cdbff";
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
