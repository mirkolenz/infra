{
  lib,
  pkgsCross,
}:
lib.extendMkDerivation {
  constructDrv = pkgsCross.wasi32.rustPlatform.buildRustPackage;
  extendDrvArgs =
    finalAttrs:
    {
      nativeBuildInputs ? [ ],
      passthru ? { },
      meta ? { },
      ...
    }:
    {
      env.RUSTFLAGS = "-C linker=wasm-ld";
      nativeBuildInputs = nativeBuildInputs ++ [ pkgsCross.wasi32.lld ];

      # cross-compiled to wasm, not a CI build target on any host platform
      meta = meta // {
        hydraPlatforms = [ ];
      };

      installPhase = ''
        runHook preInstall
        install -Dm644 target/wasm32-wasip1/release/${finalAttrs.pname}.wasm \
          "$out/share/zellij/plugins/${finalAttrs.pname}.wasm"
        runHook postInstall
      '';

      strictDeps = true;

      passthru = passthru // {
        wasm = "${finalAttrs.finalPackage}/share/zellij/plugins/${finalAttrs.pname}.wasm";
      };
    };
}
