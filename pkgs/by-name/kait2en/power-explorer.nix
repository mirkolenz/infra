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
  component = "power-explorer";
  appId = "org.t2powerexplorer.gtk";
  inherit (kait2en.modules) src;

  cargoHash = "sha256-Z2DWaTgvjrBNQgxn4DiIl5kN/Ia0IJePzF5CzUXR56M=";

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
