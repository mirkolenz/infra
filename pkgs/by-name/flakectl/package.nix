{
  lib,
  writers,
  writeShellScriptBin,
  python3Packages,
  git,
  determinate-nix,
  nix-eval-jobs,
  nix-fast-build,
  mkpasswd,
  darwin-rebuild,
  nixos-rebuild-ng,
  home-manager,
}:
let
  flakectl = writers.writePython3Bin "flakectl" {
    libraries = with python3Packages; [
      httpx2
      typer
    ];
    doCheck = false;
    makeWrapperArgs = [
      "--add-flag"
      "--nix-exe=${lib.getExe determinate-nix}"
      "--add-flag"
      "--nix-eval-jobs-exe=${lib.getExe nix-eval-jobs}"
      "--add-flag"
      "--nix-fast-build-exe=${lib.getExe nix-fast-build}"
      "--add-flag"
      "--git-exe=${lib.getExe git}"
      "--add-flag"
      "--mkpasswd-exe=${lib.getExe mkpasswd}"
      "--add-flag"
      "--update-scripts-nix=${./update-scripts.nix}"
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

  meta = prev.meta // {
    description = "Build, deploy, and update the hosts and packages of this flake";
    homepage = "https://github.com/mirkolenz/infra";
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
})
