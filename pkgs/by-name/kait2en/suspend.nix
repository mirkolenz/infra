# The Broadcom Wi-Fi and Bluetooth combo does not survive S3: this unloads the
# loaded modules before sleep and restores those same ones after resume.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/kait2en-suspend.sh
{
  kait2en,
  coreutils,
  kmod,
}:
kait2en.mkScript {
  pname = "kait2en-suspend";

  script = "scripts/fedora/kait2en-suspend.sh";

  runtimeInputs = [
    coreutils
    kmod
  ];

  meta = {
    description = "Reload the Broadcom Wi-Fi and Bluetooth modules across suspend on Apple T2 Macs";
    mainProgram = "kait2en-suspend";
  };
}
