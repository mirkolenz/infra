# Applies the CPU, iGPU, dGPU and forced idle limit steps the SMC hands out for
# the shared heatpipe, as macOS does, instead of letting the SMC escalate until
# it throttles the CPU through PROCHOT. The GUI only watches the daemon.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-zone-power
{
  kait2en,
}:
kait2en.mkGtkApp {
  appId = "org.t2zonepower.gtk";
  version = "0.1.13-unstable-2026-11-11";

  src = kait2en.fetchSource {
    rev = "9c6e22d0d5ece62351ccef78fe4bb710ab2dabaa";
    hash = "sha256-cJtrMlM1TudjB4GeDZPWZepMd0WK+B2sYBwFStk0z/o=";
    root = "apps/t2-zone-power";
    logos = [ "src/gui.rs" ];
  };

  cargoHash = "sha256-jZR0pakLlqY3SpM/mZjgkJZkD6n63ifYrwNnMRNFUNw=";

  meta = {
    description = "Apple T2 SMC power limit daemon";
    mainProgram = "t2-zonepower-gtk";
  };
}
