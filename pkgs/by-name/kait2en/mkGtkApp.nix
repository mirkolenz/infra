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
  librsvg,
}:
# The GTK apps under `apps`, which ship a desktop entry and an icon.
# Those fetched with `logos` load the KAIT2EN wordmark, a brand asset derived
# works must remove, so they show their own icon in its place, which needs the
# SVG loader of librsvg. A `build.rs` may compile the icon into a resource
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
    let
      icon = "$out/share/icons/hicolor/scalable/apps/${appId}.svg";
    in
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
      ++ lib.optional (src.logos != [ ]) librsvg
      ++ buildInputs;

      # Some entries name the binary by its Fedora path, which is optional.
      postPatch =
        lib.optionalString (src.logos != [ ]) ''
          substituteInPlace ${lib.concatMapStringsSep " " (file: "$cargoRoot/${file}") src.logos} \
            --replace-fail /usr/local/share/kait2en/kait2en-wordmark.png ${icon} \
            --replace-fail /usr/local/share/kait2en/kait2en-wordmark-light.png ${icon}
        ''
        + ''
          substituteInPlace $cargoRoot/${appId}.desktop \
            --replace-quiet /usr/local/bin/ ""
        ''
        + postPatch;

      postInstall = ''
        install -Dm444 -t $out/share/applications $cargoRoot/${appId}.desktop
        install -Dm444 $cargoRoot/assets/icons/hicolor/scalable/apps/${appId}.svg ${icon}
      ''
      + postInstall;

      # The hook would also wrap helpers under `libexec`, which run no GTK.
      dontWrapGApps = true;
      postFixup = ''
        wrapGApp $out/bin/${finalAttrs.meta.mainProgram}
      '';
    };
}
