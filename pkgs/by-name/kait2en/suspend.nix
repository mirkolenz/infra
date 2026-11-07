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

  # Upstream writes the unit from a heredoc in its installer.
  postInstall = ''
    unit=$out/lib/systemd/system/kait2en-suspend.service
    mkdir -p $out/lib/systemd/system
    awk '/<<.EOF.$/ { unit = 1; next } /^EOF$/ { unit = 0 } unit' \
      ${installer} > $unit
    substituteInPlace $unit \
      --replace-fail /usr/local/libexec/kait2en/kait2en-suspend.sh $out/bin/kait2en-suspend
  '';

  meta = {
    description = "Reload the Broadcom Wi-Fi driver across suspend on Apple T2 Macs";
    mainProgram = "kait2en-suspend";
  };
}
