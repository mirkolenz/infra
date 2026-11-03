# Shares files with Android phones over Quick Share and with Apple devices over
# AirDrop through `kait2en.drop`. Its receiver is a user unit the app switches
# on, its Quick Share hotspot helper a root one on D-Bus activation.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-airshare
{
  lib,
  kait2en,
  iproute2,
  iw,
  networkmanager,
}:
kait2en.mkGtkApp (finalAttrs: {
  appId = "org.t2airshare.gtk";
  version = "0.1.12-unstable-2026-11-02";

  src = kait2en.fetchSource {
    rev = "3206d9e4ea6cb49caba20f374954220555577fcc";
    hash = "sha256-JP1iCmIVQWhhB4FyE+vMwtFttcwMQ1nKYD70FEVHeDc=";
    root = "apps/t2-airshare";
    logos = true;
  };

  cargoHash = "sha256-qk4Tt1J4xuEQwFyLiGbVy6QRt5htNIT6Dkw2vyxdSyE=";

  # A fixed port instead of a random one, see the README.
  postPatch = ''
    substituteInPlace $cargoRoot/src/service.rs \
      --replace-fail 'TcpListener::bind(("0.0.0.0", 0))' \
        'TcpListener::bind(("0.0.0.0", ${toString finalAttrs.passthru.port}))'
    substituteInPlace $cargoRoot/integration/{*.desktop,*.nemo_action} \
      --replace-fail /usr/local/bin/ ""
    # Spawned without a PATH lookup.
    substituteInPlace $cargoRoot/integration/t2-airshare-send.py \
      --replace-fail /usr/local/bin/ $out/bin/
  '';

  postInstall = ''
    mkdir -p $out/libexec
    mv $out/bin/t2-quickshare-hotspot $out/libexec/

    install -Dm444 -t $out/share/applications $cargoRoot/integration/org.t2airshare.send.desktop
    install -Dm444 -t $out/share/nautilus-python/extensions $cargoRoot/integration/t2-airshare-send.py
    install -Dm444 -t $out/share/nemo/actions $cargoRoot/integration/t2-airshare-send.nemo_action
    # KIO only runs service menus that are executable.
    install -Dm555 $cargoRoot/integration/t2-airshare-send.servicemenu.desktop \
      $out/share/kio/servicemenus/t2-airshare-send.desktop

    install -Dm444 -t $out/share/licenses/kait2en-airshare \
      $cargoRoot/{THIRD-PARTY-NOTICES.md,proto/LICENSE-Apache-2.0,proto/LICENSE-Chromium}
  '';

  # The hotspot helper adds its interface and connection through these.
  runtimeInputs."libexec/t2-quickshare-hotspot" = [
    iproute2
    iw
    networkmanager
  ];

  passthru.port = 8771;

  meta = {
    description = "Quick Share and AirDrop for Macs with an Apple T2 security chip";
    mainProgram = "t2-airshare";
    # The Nearby protobuf definitions are Apache-2.0 and BSD-style.
    license = with lib.licenses; [
      gpl3Plus
      asl20
      bsd3
    ];
  };
})
