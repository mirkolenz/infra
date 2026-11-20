{
  lib,
  kait2en,
  glib,
  libxml2,
  makeBinaryWrapper,
  pkg-config,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
}:
# The GTK apps under `apps`, which ship a desktop entry and an icon.
# Those fetched with `logos` load the KaiT2en wordmarks from where Fedora's
# installer puts them, and a `build.rs` may compile the icon into a resource
# bundle with glib and libxml2.
lib.extendMkDerivation {
  constructDrv = kait2en.mkService;
  excludeDrvArgNames = [ "appId" ];
  extendDrvArgs =
    finalAttrs:
    {
      src,
      appId,
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      postPatch ? "",
      postInstall ? "",
      ...
    }:
    {
      nativeBuildInputs = [
        glib
        libxml2
        pkg-config
        (wrapGAppsHook4.override { makeWrapper = makeBinaryWrapper; })
      ]
      ++ nativeBuildInputs;
      buildInputs = [
        gtk4
        libadwaita
      ]
      ++ buildInputs;

      # Some entries name the binary by its Fedora path, which is optional.
      postPatch =
        lib.optionalString (src.logos != [ ]) ''
          substituteInPlace ${lib.concatMapStringsSep " " (file: "$cargoRoot/${file}") src.logos} \
            --replace-fail /usr/local/share/kait2en/ $out/share/kait2en/
        ''
        + ''
          substituteInPlace $cargoRoot/${appId}.desktop \
            --replace-quiet /usr/local/bin/ ""
        ''
        + postPatch;

      postInstall =
        lib.optionalString (src.logos != [ ]) ''
          install -Dm444 assets/kait2en-app-logo.png $out/share/kait2en/kait2en-wordmark.png
          install -Dm444 assets/kait2en-app-logo-light.png $out/share/kait2en/kait2en-wordmark-light.png
        ''
        + ''
          install -Dm444 -t $out/share/applications $cargoRoot/${appId}.desktop
          install -Dm444 -t $out/share/icons/hicolor/scalable/apps \
            $cargoRoot/assets/icons/hicolor/scalable/apps/${appId}.svg
        ''
        + postInstall;

      # The hook would also wrap helpers under `libexec`, which run no GTK.
      dontWrapGApps = true;
      postFixup = ''
        wrapGApp $out/bin/${finalAttrs.meta.mainProgram}
      '';
    };
}
