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
    "userUnits"
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
      # The units of `systemd` that belong to the graphical session.
      userUnits ? [ ],
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
        # Units under `systemd` and D-Bus files under `dbus`.
        + ''
          if [ -d $cargoRoot/systemd ]; then
            install -Dm444 -t $out/lib/systemd/system $cargoRoot/systemd/*.service
            substituteInPlace $out/lib/systemd/system/*.service --replace-fail /usr/local/ $out/
          fi
        ''
        + lib.optionalString (userUnits != [ ]) ''
          install -d $out/lib/systemd/user
          ${lib.concatMapStrings (unit: ''
            mv $out/lib/systemd/system/${unit} $out/lib/systemd/user/
          '') userUnits}
          rmdir --ignore-fail-on-non-empty $out/lib/systemd/system
        ''
        + ''

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
