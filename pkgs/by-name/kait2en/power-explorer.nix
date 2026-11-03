# Shows the device tree with the runtime power state of every node, and through
# a polkit helper the PCI power management capabilities and display lanes only
# root can read.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-power-explorer
{
  kait2en,
  hwdata,
  coreutils,
  gawk,
  gnused,
}:
kait2en.mkGtkApp {
  appId = "org.t2powerexplorer.gtk";
  version = "0.1.12-unstable-2026-11-02";

  src = kait2en.fetchSource {
    rev = "3206d9e4ea6cb49caba20f374954220555577fcc";
    hash = "sha256-IMG5D6elZFj0uYHjG+MhZ7OVqrbkjrBmBlS0DcKWxRI=";
    root = "apps/t2-power-explorer";
    logos = true;
  };

  cargoHash = "sha256-zrvhh/tp/tDp/Oerq5RzIZgRWY/9VOxJcJzCnAJ3T54=";

  # The polkit action only covers the helper at the exact path pkexec runs.
  postPatch = ''
    substituteInPlace $cargoRoot/src/collector.rs \
      --replace-fail /usr/share/hwdata/pci.ids ${hwdata}/share/hwdata/pci.ids
    substituteInPlace $cargoRoot/src/diagnostics.rs $cargoRoot/org.t2powerexplorer.policy \
      --replace-fail /usr/local/libexec/ $out/libexec/
  '';

  postInstall = ''
    install -Dm555 -t $out/libexec $cargoRoot/t2-power-explorer-status
    ${kait2en.patchScript {
      path = "$out/libexec/t2-power-explorer-status";
      runtimeInputs = [
        coreutils
        gawk
        gnused
      ];
    }}
    install -Dm444 -t $out/share/polkit-1/actions $cargoRoot/org.t2powerexplorer.policy
  '';

  meta = {
    description = "Apple T2 device power state explorer";
    mainProgram = "t2-power-explorer";
  };
}
