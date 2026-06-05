{
  flake.modules.nixvim.default =
    {
      lib',
      lib,
      config,
      ...
    }:
    {
      plugins.yazi = {
        enable = true;
        settings = {
          enable_mouse_support = true;
        };
      };
      keymaps = lib.mkIf config.plugins.yazi.enable (
        lib'.mkVimKeymaps
          {
            prefix = "Yazi ";
            raw = false;
          }
          [
            {
              key = "<leader>ef";
              mode = [
                "n"
                "v"
              ];
              action = "";
              options.desc = "Open explorer at current file";
            }
            {
              key = "<leader>ed";
              mode = [
                "n"
                "v"
              ];
              action = "cwd";
              options.desc = "Open explorer at current directory";
            }
            {
              key = "<leader>ee";
              mode = [
                "n"
                "v"
              ];
              action = "toggle";
              options.desc = "Toggle explorer";
            }
          ]
      );
    };
}
