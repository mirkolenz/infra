# The T2's internal CDC-NCM link does not survive suspend: this rebinds the
# controller around sleep and runs the hooks staged into `T2_HOOK_DIR`.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/t2-services/shared/integration/libexec/t2-ncm-sleep
{
  kait2en,
  coreutils,
  gawk,
  networkmanager,
}:
kait2en.mkScript {
  pname = "kait2en-ncm";

  script = "t2-services/shared/integration/libexec/t2-ncm-sleep";

  runtimeInputs = [
    coreutils
    gawk
    networkmanager
  ];

  meta = {
    description = "Suspend and resume helper for the Apple T2 bridge link";
    mainProgram = "t2-ncm-sleep";
  };
}
