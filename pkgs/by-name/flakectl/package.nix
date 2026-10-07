{
  lib,
  writers,
  writeShellScriptBin,
  python3Packages,
  gitMinimal,
  determinate-nix,
}:
let
  flakectl = writers.writePython3Bin "flakectl" {
    libraries = with python3Packages; [
      httpx2
      obstore
      typer
    ];
    doCheck = false;
    # What nearly every command needs, the others run tools from the flake.
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [
        determinate-nix
        gitMinimal
      ])
      "--add-flag"
      "--update-scripts-nix=${./update-scripts.nix}"
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
