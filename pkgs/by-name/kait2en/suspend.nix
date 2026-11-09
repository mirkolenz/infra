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

  version = "0.1.13-unstable-2026-11-07";

  src = kait2en.fetchSource {
    rev = "76bfd1fe4f7c085d16b421a27f2161ca52b82568";
    hash = "sha256-MlDg8HJe0O+imnvTLWGx4ZwP81ocqnPbcctsnCm3f1w=";
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
