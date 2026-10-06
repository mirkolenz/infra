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
      rev = "a88f36f452676bdcf840a5d958478e49d221c384";
      hash = "sha256-uiD5JiahqC+VJmjlqoA1BILFMoC1kl6z8QhU4mn/rDQ=";
    };
    inherit (kait2en.modules) src;
    meta = {
      description = "Detect changes to reviewed KaiT2en build and integration metadata";
      platforms = lib.platforms.unix;
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
