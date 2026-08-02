{
  lib,
  stdenvNoCC,
  bashNonInteractive,
  makeBinaryWrapper,
}:
# Assembles a plugin root herdr can register: the manifest, the entry points it
# declares, and the binary planted where it expects one, replacing the manifest's
# `[[build]]` step (which compiles or downloads a release at install time).
lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;
  excludeDrvArgNames = [
    "binary"
    "binaryPath"
    "pluginId"
    "entrypoints"
    "runtimeInputs"
    "extraWrapperArgs"
  ];
  extendDrvArgs =
    finalAttrs:
    {
      binary,
      binaryPath,
      pluginId,
      runtimeInputs,
      entrypoints ? [ ],
      extraWrapperArgs ? [ ],
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      passthru ? { },
      meta ? { },
      ...
    }:
    let
      pluginRoot = "${finalAttrs.finalPackage}/share/herdr/plugins/${finalAttrs.pname}";
      # `binaryPath` says where herdr wants the binary, the package itself says
      # what it is called, and the two are only conventionally the same
      binName = binary.meta.mainProgram;
      # herdr runs plugin commands with a minimal environment, so every entry
      # point carries its own tools.
      wrapperArgs = lib.escapeShellArgs (
        [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath runtimeInputs)
        ]
        ++ extraWrapperArgs
      );
    in
    {
      nativeBuildInputs = nativeBuildInputs ++ [ makeBinaryWrapper ];
      # herdr starts the entry points as `bash <script>`, and each wrapper hands
      # off to the original through its shebang, so bash has to resolve without
      # one from the ambient environment
      buildInputs = buildInputs ++ [ bashNonInteractive ];
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        root="$out/share/herdr/plugins/${finalAttrs.pname}"
        install -Dm644 herdr-plugin.toml "$root/herdr-plugin.toml"

        makeWrapper ${lib.getExe binary} "$out/bin/${binName}" ${wrapperArgs}

        # herdr resolves the binary under the plugin root, at the path the
        # manifest names rather than the one nixpkgs puts executables at
        install -d "$root/${dirOf binaryPath}"
        ln -s "$out/bin/${binName}" "$root/${binaryPath}"

        ${lib.concatMapStrings (entrypoint: ''
          install -Dm755 ${entrypoint} "$root/${entrypoint}"
          wrapProgram "$root/${entrypoint}" ${wrapperArgs}
        '') entrypoints}
        runHook postInstall
      '';

      strictDeps = true;

      # `binary` stays reachable for `nix-update --subpackage binary`, which
      # resolves it as an attribute of the plugin
      passthru = passthru // {
        inherit pluginId binary;
        root = pluginRoot;
        manifest = "${pluginRoot}/herdr-plugin.toml";
      };

      # the entry points are shell wrappers, so the windows halves of the
      # manifests are out of reach whatever the binary's toolchain supports
      meta = {
        platforms = lib.platforms.unix;
        mainProgram = binName;
      }
      // meta;
    };
}
