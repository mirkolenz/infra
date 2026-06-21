{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      lib,
      lib',
      ...
    }:
    {
      programs.zed-editor.enable = lib.mkDefault (
        pkgs.stdenv.isLinux && config.custom.features.withDisplay
      );
      # Zed rewrites these JSON files at runtime, which fails on read-only store
      # symlinks. Install writable copies instead; they reset on each rebuild.
      home.activation.zedFiles = lib'.mkMutableFiles {
        inherit config;
        files =
          map
            (name: {
              source = ./. + "/${name}";
              target = "${config.xdg.configHome}/zed/${name}";
            })
            [
              "debug.json"
              "keymap.json"
              "settings.json"
              "tasks.json"
            ];
      };
      home.shellAliases = lib.mkIf config.programs.zed-editor.enable {
        zed = "zeditor";
      };
    };
}
