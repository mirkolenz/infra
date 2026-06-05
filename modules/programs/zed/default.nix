{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.zed-editor = {
        enable = lib.mkDefault (pkgs.stdenv.isLinux && config.custom.features.withDisplay);
        mutableUserDebug = false;
        mutableUserKeymaps = false;
        mutableUserSettings = false;
        mutableUserTasks = false;
      };
      xdg.configFile = {
        "zed/debug.json".source = ./debug.json;
        "zed/keymap.json".source = ./keymap.json;
        "zed/settings.json".source = ./settings.json;
        "zed/tasks.json".source = ./tasks.json;
      };
      home.shellAliases = lib.mkIf config.programs.zed-editor.enable {
        zed = "zeditor";
      };
      home.sessionVariables = lib.mkIf config.programs.zed-editor.enable {
        EDITOR = lib.mkForce "zed --wait";
        VISUAL = lib.mkForce "zed --wait";
      };
    };
}
