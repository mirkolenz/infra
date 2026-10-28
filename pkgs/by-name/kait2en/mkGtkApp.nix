{
  lib,
  kait2en,
  glib,
  libxml2,
  pkg-config,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
}:
# The GTK apps under `apps`, which ship a desktop entry and an icon, and load
# the KaiT2en wordmarks from where Fedora's installer puts them. A `build.rs`
# compiles the icon into a resource bundle with glib and libxml2.
lib.extendMkDerivation {
  constructDrv = kait2en.mkService;
  excludeDrvArgNames = [ "appId" ];
  extendDrvArgs =
    finalAttrs:
    {
      component,
      appId,
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      postPatch ? "",
      postInstall ? "",
      ...
    }:
    let
      root = "apps/t2-${component}";
      assets = "share/kait2en";
    in
    {
      inherit root;

      nativeBuildInputs = [
        glib
        libxml2
        pkg-config
        wrapGAppsHook4
      ]
      ++ nativeBuildInputs;
      buildInputs = [
        gtk4
        libadwaita
      ]
      ++ buildInputs;

      # Some entries name the binary by its Fedora path, which is optional.
      postPatch = ''
        substituteInPlace $(grep -rl /usr/local/${assets}/ ${root}/src) \
          --replace-fail /usr/local/${assets}/ $out/${assets}/
        substituteInPlace ${root}/${appId}.desktop \
          --replace-quiet /usr/local/bin/ ""
      ''
      + postPatch;

      postInstall = ''
        install -Dm444 assets/kait2en-app-logo.png $out/${assets}/kait2en-wordmark.png
        install -Dm444 assets/kait2en-app-logo-light.png $out/${assets}/kait2en-wordmark-light.png
        install -Dm444 -t $out/share/applications ${root}/${appId}.desktop
        install -Dm444 -t $out/share/icons/hicolor/scalable/apps \
          ${root}/assets/icons/hicolor/scalable/apps/${appId}.svg

        # The units of a daemon mode of the same binary.
        if [ -d ${root}/systemd ]; then
          install -Dm444 -t $out/lib/systemd/system ${root}/systemd/*.service
          substituteInPlace $out/lib/systemd/system/*.service \
            --replace-fail /usr/local/bin/ $out/bin/
        fi
      ''
      + postInstall;

      # The hook would also wrap helpers under `libexec`, which run no GTK.
      dontWrapGApps = true;
      postFixup = ''
        wrapGApp $out/bin/${finalAttrs.meta.mainProgram}
      '';
    };
}
