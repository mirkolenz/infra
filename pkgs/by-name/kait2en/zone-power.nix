# Applies the CPU, iGPU, dGPU and forced idle limit steps the SMC hands out for
# the shared heatpipe, as macOS does, instead of letting the SMC escalate until
# it throttles the CPU through PROCHOT. The GUI only watches the daemon.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-zone-power
{
  kait2en,
}:
kait2en.mkGtkApp {
  appId = "org.t2zonepower.gtk";
  version = "0.1.12-unstable-2026-11-02";

  src = kait2en.fetchSource {
    rev = "3206d9e4ea6cb49caba20f374954220555577fcc";
    hash = "sha256-VD0zcVKvN6sH+f42jCZ/ASnEjaTQGLKEED9djGBCf4E=";
    root = "apps/t2-zone-power";
    logos = true;
  };

  cargoHash = "sha256-wznUu7QKYZsKl+CLMPvPfK6aOJs96a9Pqwi0SqxR34c=";

  meta = {
    description = "Apple T2 SMC power limit daemon";
    mainProgram = "t2-zonepower-gtk";
  };
}
