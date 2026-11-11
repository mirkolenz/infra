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
  version = "0.1.13-unstable-2026-11-11";

  src = kait2en.fetchSource {
    rev = "9c6e22d0d5ece62351ccef78fe4bb710ab2dabaa";
    hash = "sha256-yqjXp4vHkklfXzlUkz8QT5gm/HYMD/R9N9oHk80p6bA=";
    root = "t2-services/t2-ave";
    bridgexpc = true;
    # The AVE driver, built by `kait2en.modules`.
    paths = [ "!t2-services/t2-ave/kernel/" ];
  };

  cargoHash = "sha256-A1Ych+V2fU99G9vRr2vNrmNmU9XTCIvYxLngxLiZYUo=";

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
