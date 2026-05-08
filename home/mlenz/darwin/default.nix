{
  pkgs,
  lib,
  lib',
  ...
}:
{
  imports = lib'.flocken.getModules ./.;

  home.packages = with pkgs; [
    mas
    restic-browser-bin
    undmg
    rcodesign
    container
    mole-mac
    nvtopPackages.apple
    (writeShellApplication {
      name = "scansnap-reset";
      text = /* bash */ ''
        pkill -f ScanSnap
        open --hide /Applications/ScanSnapHomeMain.app
      '';
    })
    (writeShellApplication {
      name = "nixos";
      text = /* bash */ ''
        exec orbctl run --machine nixos "$@"
      '';
    })
  ];
  # xdg.binFile = {
  #   git.source = lib.getExe config.programs.git.package;
  #   nvim.source = lib.getExe config.programs.nixvim.build.package;
  #   restic.source = lib.getExe pkgs.restic;
  # };
  home.file = {
    "Library/Group Containers/group.com.apple.AppleSpell/Library/Spelling/LocalDictionary".source =
      ../dictionary.txt;
  };
  home.shellAliases = {
    copy = /* bash */ ''${lib.getExe' pkgs.coreutils "tr"} -d '\n' | pbcopy'';
  };
  targets.darwin.copyApps.enableChecks = false; # requires sudo during activation
}
