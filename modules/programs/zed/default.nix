{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      lib,
      ...
    }@args:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
      llamaCpp = args.osConfig.services.llama-cpp or { enable = false; };
    in
    lib.mkIf config.custom.features.graphical.enable {
      custom.zed = {
        enable = true;
        # darwin installs the app through homebrew
        package = lib.mkIf (!isLinux) null;
        settings = import ./_settings.nix { inherit config lib llamaCpp; };
        keymap = import ./_keymap.nix;
        tasks = import ./_tasks.nix;
        debug = import ./_debug.nix;
      };

      home.shellAliases = lib.mkIf isLinux {
        zed = "zeditor";
      };
    };
}
