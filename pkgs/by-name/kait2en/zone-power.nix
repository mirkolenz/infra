# Applies the CPU, iGPU, dGPU and forced idle limit steps the SMC hands out for
# the shared heatpipe, as macOS does, instead of letting the SMC escalate until
# it throttles the CPU through PROCHOT. The GUI only watches the daemon.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-zone-power
{
  kait2en,
}:
kait2en.mkGtkApp {
  component = "zone-power";
  appId = "org.t2zonepower.gtk";
  inherit (kait2en.modules) src;

  cargoHash = "sha256-82x/yS+aEErpp09Na0ZM8WCDDWFMZjQlG+trRg64ub0=";

  meta = {
    description = "Apple T2 SMC power limit daemon";
    mainProgram = "t2-zonepower-gtk";
  };
}
