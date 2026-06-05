{ lib, ... }:
lib.nixvim.plugins.mkNeovimPlugin {
  name = "multicursor-nvim";

  extraOptions = {
    keymapsLayer = lib.mkOption {
      default = [ ];
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            key = lib.mkOption {
              type = lib.types.str;
            };
            mode = lib.nixvim.keymaps.mkModeOption "n";
            action = lib.mkOption {
              type = lib.types.either lib.types.str lib.types.rawLua;
            };
          };
        }
      );
    };
  };

  extraConfig = cfg: {
    plugins.multicursor-nvim.luaConfig.content = /* lua */ ''
      require("multicursor-nvim").addKeymapLayer(function(layerSet)
        ${lib.concatMapStringsSep "\n" (
          {
            key,
            mode,
            action,
          }:
          if lib.isAttrs action then
            /* lua */ ''
              layerSet(${lib.nixvim.toLuaObject mode}, "${key}", function()
                ${action.__raw}
              end)
            ''
          else
            /* lua */ ''
              layerSet(${lib.nixvim.toLuaObject mode}, "${key}", require("multicursor-nvim").${action})
            ''
        ) cfg.keymapsLayer}
      end)
    '';
  };

  maintainers = with lib.maintainers; [ mirkolenz ];
}
