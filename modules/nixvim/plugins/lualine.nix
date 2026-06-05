{
  flake.modules.nixvim.default = {
    plugins.lualine = {
      enable = true;
      settings = {
        options = {
          globalstatus = true;
        };
        tabline = {
          lualine_a = [ "tabs" ];
          lualine_b = [ "buffers" ];
        };
      };
    };
  };
}
