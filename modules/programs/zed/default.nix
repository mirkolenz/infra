{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      lib,
      lib',
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [
        pkgs.zed-editor
      ];

      # Zed rewrites these JSON files at runtime, which fails on read-only store
      # symlinks. Install writable copies instead; they reset on each rebuild.
      home.activation.setupZedFiles = lib'.mkMutableFiles {
        inherit config;
        files =
          lib.mapAttrsToList
            (name: source: {
              inherit source;
              target = "${config.xdg.configHome}/zed/${name}";
            })
            {
              "debug.json" = ./debug.json;
              "keymap.json" = ./keymap.json;
              "settings.json" = pkgs.writeText "settings.json" (
                lib.replaceStrings
                  [ "@fontFamily@" ''"@fontSize@"'' ]
                  [ config.custom.font.family (toString config.custom.font.size) ]
                  (lib.readFile ./settings.json)
              );
              "tasks.json" = ./tasks.json;
            };
      };

      home.shellAliases = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        zed = "zeditor";
      };
    };
}
