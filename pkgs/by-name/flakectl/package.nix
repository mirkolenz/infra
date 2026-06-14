{
  lib,
  writers,
  writeShellScriptBin,
  python3Packages,
  gh,
  git,
  determinate-nix,
  darwin-rebuild,
  nixos-rebuild-ng,
  home-manager,
}:
let
  flakectl = writers.writePython3Bin "flakectl" {
    libraries = with python3Packages; [ typer ];
    doCheck = false;
    makeWrapperArgs = [
      "--add-flag"
      "--nix-exe=${lib.getExe determinate-nix}"
      "--add-flag"
      "--nix-shell-exe=${lib.getExe' determinate-nix "nix-shell"}"
      "--add-flag"
      "--git-exe=${lib.getExe git}"
      "--add-flag"
      "--gh-exe=${lib.getExe gh}"
      "--add-flag"
      "--darwin-builder=${lib.getExe darwin-rebuild}"
      "--add-flag"
      "--linux-builder=${lib.getExe nixos-rebuild-ng}"
      "--add-flag"
      "--home-builder=${lib.getExe home-manager}"
    ];
  } ./script.py;
in
flakectl.overrideAttrs (prev: {
  # Wrap flakectl with persistent GNU-style flags, leaving "$@" for the
  # subcommand, so downstream flakes drive their own flake without re-deriving
  # the wrapper: `pkgs.flakectl.withFlags { flake = self.outPath; cache = "..."; }`.
  passthru = (prev.passthru or { }) // {
    withFlags =
      flags:
      writeShellScriptBin flakectl.meta.mainProgram ''
        exec ${lib.getExe flakectl} ${lib.cli.toCommandLineShellGNU { } flags} "$@"
      '';
  };
})
