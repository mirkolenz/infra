{
  lib,
  stdenv,
  makeBinaryWrapper,
  prev,
}:
prev.virt-manager.overrideAttrs (oldAttrs: {
  nativeBuildInputs =
    (oldAttrs.nativeBuildInputs or [ ])
    ++ (lib.optional stdenv.hostPlatform.isDarwin makeBinaryWrapper);
  postInstall =
    (oldAttrs.postInstall or "")
    + (lib.optionalString stdenv.hostPlatform.isDarwin ''
      wrapProgram $out/bin/virt-manager \
        --set GSETTINGS_BACKEND keyfile
    '');
  meta = oldAttrs.meta // {
    hydraPlatforms = lib.platforms.darwin;
  };
})
