{
  lib,
  rustPlatform,
  kait2en,
  makeBinaryWrapper,
}:
# The Rust daemons under `t2-services` and `apps`. Each crate sits in a
# subdirectory of its sparse checkout, which keeps upstream's layout for path
# dependencies reaching out of it.
# Callers declare `version` and `src` so nix-update writes to their files.
lib.extendMkDerivation {
  constructDrv = rustPlatform.buildRustPackage;
  excludeDrvArgNames = [
    "integration"
    "bridge"
    "runtimeInputs"
  ];
  extendDrvArgs =
    _finalAttrs:
    {
      # Its `root` is the crate, named `t2-<component>` upstream.
      src,
      # Upstream's units and configuration, from its `install-integration`.
      integration ? false,
      # A daemon on the bridge link, which starts with it instead of waiting for
      # `network-online.target`, see `apple-t2/bridge.nix`.
      bridge ? false,
      # The packages each program, relative to the output, finds on its PATH.
      runtimeInputs ? { },
      nativeBuildInputs ? [ ],
      meta ? { },
      postInstall ? "",
      ...
    }:
    let
      inherit (src) root;
      component = lib.removePrefix "t2-" (baseNameOf root);
    in
    {
      pname = "kait2en-${component}";

      cargoRoot = root;
      buildAndTestSubdir = root;

      nativeBuildInputs = nativeBuildInputs ++ lib.optional (runtimeInputs != { }) makeBinaryWrapper;

      postInstall =
        kait2en.installLicenses "kait2en-${component}"
        # Units under `systemd` and D-Bus files under `dbus`, a unit tied to
        # the graphical session being a user unit.
        + ''
          if [ -d $cargoRoot/systemd ]; then
            for unit in $cargoRoot/systemd/*.service; do
              kind=system
              if grep -q graphical-session.target "$unit"; then
                kind=user
              fi

              install -Dm444 -t $out/lib/systemd/$kind "$unit"
              substituteInPlace "$out/lib/systemd/$kind/''${unit##*/}" \
                --replace-fail /usr/local/ $out/
            done
          fi

          if [ -d $cargoRoot/dbus ]; then
            install -Dm444 -t $out/share/dbus-1/system.d $cargoRoot/dbus/*.conf
            install -Dm444 -t $out/share/dbus-1/system-services $cargoRoot/dbus/*.service
          fi
        ''
        + lib.optionalString integration ''
          make -C $cargoRoot install-integration PREFIX=$out SYSCONFDIR=$out/etc
        ''
        + lib.optionalString bridge ''
          substituteInPlace $out/lib/systemd/system/*.service \
            --replace-fail ' network-online.target' ""
        ''
        + postInstall
        + lib.concatMapAttrsStringSep "\n" (program: packages: ''
          wrapProgram $out/${program} --prefix PATH : ${lib.makeBinPath packages}
        '') runtimeInputs;

      __structuredAttrs = true;

      meta = kait2en.commonMeta // meta;
    };
}
