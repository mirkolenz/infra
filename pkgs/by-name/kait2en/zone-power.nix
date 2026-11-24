# Applies the CPU, iGPU, dGPU and forced idle limit steps the SMC hands out for
# the shared heatpipe, as macOS does, instead of letting the SMC escalate until
# it throttles the CPU through PROCHOT. The GUI only watches the daemon.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-zone-power
{
  kait2en,
}:
kait2en.mkGtkApp {
  appId = "org.t2zonepower.gtk";
  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-SfEkwwU5Fb/cndOLZl1fi2tFD4aLcBU/D1c4jkG0ZvE=";
    root = "apps/t2-zone-power";
    logos = [ "src/gui.rs" ];
  };

  cargoHash = "sha256-jZR0pakLlqY3SpM/mZjgkJZkD6n63ifYrwNnMRNFUNw=";

  meta = {
    description = "Apple T2 SMC power limit daemon";
    mainProgram = "t2-zonepower-gtk";
  };
}
