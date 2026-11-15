# The BCM4350 Wi-Fi of the MacBookPro14,1 does not survive S3: this unloads its
# driver before sleep and restores it after resume, other Macs are left alone.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/kait2en-suspend.sh
{
  kait2en,
  coreutils,
  kmod,
}:
let
  script = "scripts/fedora/kait2en-suspend.sh";
  installer = "scripts/fedora/install-suspend-service.sh";
in
kait2en.mkScript {
  pname = "kait2en-suspend";

  version = "0.1.14-unstable-2026-11-15";

  src = kait2en.fetchSource {
    rev = "260a559597a7bd3b168a9a251a2248d97aadd957";
    hash = "sha256-LBeDDnLSUztXTKzoyi3skdAaKZ+Lyu3PxUQAuBgZSyI=";
    # The installer is only tracked, so the check flags a change to the unit
    # `apple-t2/suspend.nix` mirrors.
    paths = [
      script
      installer
    ];
  };

  inherit script;

  runtimeInputs = [
    coreutils
    kmod
  ];

  meta = {
    description = "Reload the Broadcom Wi-Fi driver across suspend on Apple T2 Macs";
    mainProgram = "kait2en-suspend";
  };
}
