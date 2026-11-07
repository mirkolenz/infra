# Userspace half of the T2's audio/video engine: the driver in `kait2en.modules`
# exposes the device, this daemon opens the sessions and ships the sleep hook
# closing them.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-ave
{
  lib,
  kait2en,
  coreutils,
  kmod,
}:
kait2en.mkService {
  version = "0.1.13-unstable-2026-11-07";

  src = kait2en.fetchSource {
    rev = "76bfd1fe4f7c085d16b421a27f2161ca52b82568";
    hash = "sha256-K9wZbPg1Iftv8wDTUfoF8Q1bbkkVu9QucO472R96Mrk=";
    root = "t2-services/t2-ave";
    bridgexpc = true;
    # The AVE driver, built by `kait2en.modules`.
    paths = [ "!t2-services/t2-ave/kernel/" ];
  };

  cargoHash = "sha256-mQ7D13m0wGRb7uW6s/sE22AjIvsfIUK5HObUoz2ey1I=";

  integration = true;
  bridge = true;

  # The hook needs `t2remote` and `timeout` on a PATH sleep does not provide.
  postInstall = ''
    substituteInPlace $out/lib/systemd/system/kait2en-t2-remote.service \
      --replace-fail /usr/sbin/modprobe ${lib.getExe' kmod "modprobe"}
    ${kait2en.patchScript {
      path = "$out/libexec/t2-services/sleep.d/t2-ave";
      runtimeInputs = [ coreutils ];
      extraPaths = [ "$out/bin" ];
    }}
  '';

  meta = {
    description = "Apple T2 AVE service daemon";
    mainProgram = "t2remote";
  };
}
