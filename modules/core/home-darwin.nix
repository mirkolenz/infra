# macOS home-manager: packages, helper scripts, spelling dictionary.
{
  flake.modules.homeManager.darwin =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home.packages = with pkgs; [
        mas
        undmg
        rcodesign
        container
        mole-mac
        nvtopPackages.apple
      ];
      custom.commands = {
        scansnap-reset.text = /* bash */ ''
          # @describe Restart ScanSnap Home in the background

          pkill -f ScanSnap
          open --hide /Applications/ScanSnapHomeMain.app
        '';
        nixos.text = /* bash */ ''
          # @describe Run a command in the NixOS machine of OrbStack
          # @arg args~ Arguments of orbctl run

          exec orbctl run --machine nixos "$@"
        '';
      };
      home.file = {
        "Library/Group Containers/group.com.apple.AppleSpell/Library/Spelling/LocalDictionary" = {
          source = ./dictionary.txt;
          # AppleSpell caches the dictionary and is relaunched on demand.
          onChange = "run /usr/bin/killall AppleSpell || true";
        };
      };
      home.shellAliases = {
        copy = "${lib.getExe config.custom.commands.noeol} | pbcopy";
      };
      targets.darwin.copyApps.enableChecks = false; # requires sudo during activation
    };
}
