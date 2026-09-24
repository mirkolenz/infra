# Runs feature hooks around suspend. The T2's CDC-NCM link now survives
# through the virtual USB host controller's reset-resume path.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/t2-services/shared/integration/libexec/t2-ncm-sleep
{
  kait2en,
  coreutils,
}:
kait2en.mkScript {
  pname = "kait2en-ncm";

  script = "t2-services/shared/integration/libexec/t2-ncm-sleep";

  runtimeInputs = [ coreutils ];

  meta = {
    description = "Apple T2 feature sleep hook runner";
    mainProgram = "t2-ncm-sleep";
  };
}
