# Parks the dGPU through vga_switcheroo and powers it up across S3, which it
# does not survive powered down.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/apps/t2-dgpu-control/contrib/t2-dgpu-control-helper
{
  kait2en,
  coreutils,
  gawk,
}:
kait2en.mkScript {
  pname = "kait2en-dgpu";

  script = "apps/t2-dgpu-control/contrib/t2-dgpu-control-helper";

  runtimeInputs = [
    coreutils
    gawk
  ];

  meta = {
    description = "Apple T2 discrete GPU power control";
    mainProgram = "t2-dgpu-control-helper";
  };
}
