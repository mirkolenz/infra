{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
    in
    lib.mkIf config.custom.features.graphical.enable {
      custom.zed = {
        enable = true;
        # darwin installs the app through homebrew
        package = lib.mkIf (!isLinux) null;
        settings = import ./_settings.nix { inherit config lib; };
        keymap = import ./_keymap.nix;
        tasks = import ./_tasks.nix;
        debug = import ./_debug.nix;
      };

      home.shellAliases = lib.mkIf isLinux {
        zed = "zeditor";
      };
    };
}
