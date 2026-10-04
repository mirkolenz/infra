{
  lib,
  kait2en,
  pkg-config,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
}:
# The GTK apps under `apps`, which ship a desktop entry and an icon, and load
# the KaiT2en wordmark from where Fedora's installer puts it.
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
      wordmark = "share/kait2en/kait2en-wordmark.png";
    in
    {
      inherit root;

      nativeBuildInputs = [
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
        substituteInPlace $(grep -rl /usr/local/${wordmark} ${root}/src) \
          --replace-fail /usr/local/${wordmark} $out/${wordmark}
        substituteInPlace ${root}/${appId}.desktop \
          --replace-quiet /usr/local/bin/ ""
      ''
      + postPatch;

      postInstall = ''
        install -Dm444 website/static/img/kait2en-wordmark.png $out/${wordmark}
        install -Dm444 -t $out/share/applications ${root}/${appId}.desktop
        install -Dm444 -t $out/share/icons/hicolor/scalable/apps \
          ${root}/assets/icons/hicolor/scalable/apps/${appId}.svg
      ''
      + postInstall;

      # The hook would also wrap helpers under `libexec`, which run no GTK.
      dontWrapGApps = true;
      postFixup = ''
        wrapGApp $out/bin/${finalAttrs.meta.mainProgram}
      '';
    };
}
