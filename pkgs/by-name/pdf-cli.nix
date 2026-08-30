{
  lib,
  stdenv,
  prev,
}:
prev.pdf-cli.overrideAttrs (oldAttrs: {
  # Go does not expose syscall.Dup2 on linux/arm64, whose kernel ABI only provides dup3, so the
  # stderr redirection around the fitz document open fails to compile there.
  # Dup3 exists on every linux architecture and behaves identically here because the target fd is
  # always the literal 2, never equal to the source fd.
  # https://hydra.nixos.org/job/nixpkgs/unstable/pdf-cli.aarch64-linux
  postPatch =
    (oldAttrs.postPatch or "")
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      substituteInPlace internal/viewer/viewer.go \
        --replace-fail "syscall.Dup2(int(devNull.Fd()), 2)" "syscall.Dup3(int(devNull.Fd()), 2, 0)" \
        --replace-fail "syscall.Dup2(savedStderr, 2)" "syscall.Dup3(savedStderr, 2, 0)"
    '';

  meta = oldAttrs.meta // {
    hydraPlatforms = lib.platforms.linux;
  };
})
