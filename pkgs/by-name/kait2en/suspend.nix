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

  # Upstream writes the unit from a heredoc in its installer.
  postInstall = ''
    unit=$out/lib/systemd/system/kait2en-suspend.service
    mkdir -p $out/lib/systemd/system
    awk '/<<.EOF.$/ { unit = 1; next } /^EOF$/ { unit = 0 } unit' \
      scripts/fedora/install-suspend-service.sh > $unit
    substituteInPlace $unit \
      --replace-fail /usr/local/libexec/kait2en/kait2en-suspend.sh $out/bin/kait2en-suspend
  '';

  meta = {
    description = "Reload the Broadcom Wi-Fi and Bluetooth modules across suspend on Apple T2 Macs";
    mainProgram = "kait2en-suspend";
  };
}
