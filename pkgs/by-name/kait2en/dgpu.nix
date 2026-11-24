# Parks the dGPU through vga_switcheroo and powers it up across S3, which it
# does not survive powered down.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/apps/t2-dgpu-control/contrib/t2-dgpu-control-helper
{
  kait2en,
  coreutils,
  e2fsprogs,
  gawk,
  gnugrep,
  systemd,
}:
let
  script = "apps/t2-dgpu-control/contrib/t2-dgpu-control-helper";
in
kait2en.mkScript {
  pname = "kait2en-dgpu";

  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-/U6837GgRrsvBQV3R7B6QN4VCep4eiWTrgWcdfkR4bA=";
    paths = [
      script
      "apps/t2-dgpu-control/systemd/"
    ];
  };

  inherit script;

  runtimeInputs = [
    coreutils
    e2fsprogs
    gawk
    gnugrep
    systemd
  ];

  # The AMDGPU profile units are left out, `apple-t2/graphics.nix` caps a
  # powered dGPU with a udev rule instead.
  postInstall = ''
    install -Dm444 -t $out/lib/systemd/system \
      apps/t2-dgpu-control/systemd/kait2en-dgpu-{off,suspend}.service
    substituteInPlace $out/lib/systemd/system/*.service \
      --replace-fail /usr/local/libexec/t2-dgpu-control-helper $out/bin/t2-dgpu-control-helper
  '';

  meta = {
    description = "Apple T2 discrete GPU power control";
    mainProgram = "t2-dgpu-control-helper";
  };
}
