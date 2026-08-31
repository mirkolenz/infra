{
  lib,
  stdenv,
  prev,
}:
prev.pdf-cli.overrideAttrs (oldAttrs: {
  postPatch =
    (oldAttrs.postPatch or "")
    + ''
      # Ghostty speaks the kitty graphics protocol, but it matches no case in the TERM_PROGRAM
      # switch and then falls into the TERM=xterm* one, which caps the render at 100 DPI without
      # supersampling and delegates placement to go-termimg, which disagrees with the centering
      # offset pdf-cli itself printed. Detect it alongside kitty, before the xterm case is reached.
      # Fixed upstream in 219ff48, after the v.3.0 tag.
      substituteInPlace internal/terminal/terminal.go \
        --replace-fail 'os.Getenv("KITTY_WINDOW_ID") != ""' 'os.Getenv("TERM_PROGRAM") == "ghostty" || strings.Contains(os.Getenv("TERM"), "ghostty") || os.Getenv("KITTY_WINDOW_ID") != ""'
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      # Go does not expose syscall.Dup2 on linux/arm64, whose kernel ABI only provides dup3, so the
      # stderr redirection around the fitz document open fails to compile there.
      # Dup3 exists on every linux architecture and behaves identically here because the target fd is
      # always the literal 2, never equal to the source fd.
      # https://hydra.nixos.org/job/nixpkgs/unstable/pdf-cli.aarch64-linux
      substituteInPlace internal/viewer/viewer.go \
        --replace-fail "syscall.Dup2(int(devNull.Fd()), 2)" "syscall.Dup3(int(devNull.Fd()), 2, 0)" \
        --replace-fail "syscall.Dup2(savedStderr, 2)" "syscall.Dup3(savedStderr, 2, 0)"
    '';

  meta = oldAttrs.meta // {
    hydraPlatforms = lib.platforms.linux;
  };
})
