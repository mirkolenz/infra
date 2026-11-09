# Applies the CPU, iGPU, dGPU and forced idle limit steps the SMC hands out for
# the shared heatpipe, as macOS does, instead of letting the SMC escalate until
# it throttles the CPU through PROCHOT. The GUI only watches the daemon.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-zone-power
{
  kait2en,
}:
kait2en.mkGtkApp {
  appId = "org.t2zonepower.gtk";
  version = "0.1.13-unstable-2026-11-08";

  src = kait2en.fetchSource {
    rev = "8de95468f08c6db37924bcb8f9adc12c769add71";
    hash = "sha256-i+pxfFqpIwb2m72UgBLIA6y+OzRFOuWRF+wHttXjYVM=";
    root = "apps/t2-zone-power";
    logos = [ "src/gui.rs" ];
  };

  cargoHash = "sha256-wznUu7QKYZsKl+CLMPvPfK6aOJs96a9Pqwi0SqxR34c=";

  meta = {
    description = "Apple T2 SMC power limit daemon";
    mainProgram = "t2-zonepower-gtk";
  };
}
