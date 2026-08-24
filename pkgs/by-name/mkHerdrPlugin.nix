{
  lib,
  stdenvNoCC,
  makeBinaryWrapper,
}:
# Assembles a plugin root herdr can register: the manifest, the files it reads,
# and the programs it runs planted where it expects them, replacing the
# manifest's `[[build]]` step (which compiles or downloads a release at install
# time).
lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;
  excludeDrvArgNames = [
    "binary"
    "binaryPath"
    "interpreters"
    "pluginId"
    "pluginFiles"
    "runtimeInputs"
    "extraWrapperArgs"
  ];
  extendDrvArgs =
    finalAttrs:
    {
      pluginId,
      runtimeInputs,
      binary ? null,
      binaryPath ? null,
      interpreters ? [ ],
      pluginFiles ? [ ],
      extraWrapperArgs ? [ ],
      nativeBuildInputs ? [ ],
      passthru ? { },
      meta ? { },
      ...
    }:
    let
      pluginRoot = "${finalAttrs.finalPackage}/share/herdr/plugins/${finalAttrs.pname}";
      # herdr runs plugin commands with a minimal environment, so every program
      # it starts carries its own tools
      wrapperArgs = lib.escapeShellArgs (
        [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath runtimeInputs)
        ]
        ++ extraWrapperArgs
      );
      plant = program: path: ''
        install -d "$root/$(dirname ${path})"
        makeWrapper ${lib.getExe program} "$root/${path}" ${wrapperArgs}
      '';
    in
    {
      nativeBuildInputs = nativeBuildInputs ++ [ makeBinaryWrapper ];
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        root="$out/share/herdr/plugins/${finalAttrs.pname}"
        install -Dm644 herdr-plugin.toml "$root/herdr-plugin.toml"

        # the manifest names the binary at a path of its own choosing rather than
        # the one nixpkgs puts executables at
        ${lib.optionalString (binary != null) (plant binary binaryPath)}
        # naming an interpreter on its own instead leaves herdr to resolve it from
        # the ambient environment, so repoint those commands at our copy
        ${lib.concatMapStrings (
          interpreter:
          let
            name = interpreter.meta.mainProgram;
          in
          plant interpreter "bin/${name}"
          + ''
            substituteInPlace "$root/herdr-plugin.toml" \
              --replace-fail 'command = ["${name}",' 'command = ["./bin/${name}",'
          ''
        ) interpreters}
        # the interpreters read these, so they ship as they are
        ${lib.concatMapStrings (path: ''
          install -d "$root/$(dirname ${path})"
          cp -R ${path} "$root/${path}"
        '') pluginFiles}
        runHook postInstall
      '';

      strictDeps = true;

      # `binary` stays reachable for `nix-update --subpackage binary`, which
      # resolves it as an attribute of the plugin
      passthru =
        passthru
        // {
          inherit pluginId;
          root = pluginRoot;
          manifest = "${pluginRoot}/herdr-plugin.toml";
        }
        // lib.optionalAttrs (binary != null) { inherit binary; };

      # the plugins reach herdr through shell entry points, so the windows halves
      # of the manifests are out of reach whatever the binary's toolchain supports
      meta = {
        platforms = lib.platforms.unix;
      }
      // meta;
    };
}
