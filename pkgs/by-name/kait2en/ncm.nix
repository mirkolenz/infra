# The integration shared by the daemons on the T2's CDC-NCM link: a udev rule
# bringing it up outside NetworkManager, and a sleep unit running their hooks.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/shared
{
  lib,
  stdenvNoCC,
  kait2en,
  udevCheckHook,
  coreutils,
  iproute2,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kait2en-ncm";
  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-gmwzXjcXkqXeaCyxq7wmlyFKO03VMWm+e1mr7AUkUhk=";
    root = "t2-services/shared";
    paths = [
      "!t2-services/shared/protocols/"
      # Installed by the Makefile and removed again below.
      "packaging/lifecycle/kait2en-lifecycle.py"
    ];
  };

  dontConfigure = true;
  dontBuild = true;

  makeFlags = [
    "-C"
    finalAttrs.src.root
    "PREFIX=${placeholder "out"}"
    "SYSCONFDIR=${placeholder "out"}/etc"
  ];

  # Upstream's package lifecycle has nothing to migrate here.
  postInstall = ''
    rm -r $out/libexec/t2-services/{lifecycle.py,migration,package-actions}
    # `apple-t2/bridge.nix` declares its NetworkManager settings.
    rm -r $out/etc
    ${kait2en.patchScript {
      path = "$out/libexec/t2-services/t2-ncm-sleep";
      runtimeInputs = [ coreutils ];
    }}
    substituteInPlace $out/lib/udev/rules.d/90-t2-services-ncm.rules \
      --replace-fail /usr/sbin/ip ${lib.getExe' iproute2 "ip"}
    ${kait2en.installLicenses finalAttrs}
  '';

  nativeInstallCheckInputs = [ udevCheckHook ];
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  meta = kait2en.commonMeta // {
    description = "Apple T2 CDC-NCM link integration";
  };
})
