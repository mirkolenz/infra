{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      lib,
      lib',
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      programs.zed-editor.enable = false;

      home.packages = lib.mkIf pkgs.stdenv.isLinux [
        pkgs.zed-editor
      ];

      # Zed rewrites these JSON files at runtime, which fails on read-only store
      # symlinks. Install writable copies instead; they reset on each rebuild.
      home.activation.setupZedFiles = lib'.mkMutableFiles {
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

      home.shellAliases = lib.mkIf pkgs.stdenv.isLinux {
        zed = "zeditor";
      };
    };
}
