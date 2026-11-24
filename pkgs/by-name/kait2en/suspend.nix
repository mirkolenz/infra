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

  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-rscExhVrj/Hve3QXrSyW18g7xQalfG8i9BsRPqQ0UM8=";
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
