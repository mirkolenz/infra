{
  flake.modules.nixvim.default = {
    performance = {
      # causes increased build time in ci
      byteCompileLua = {
        enable = false;
        configs = true;
        initLua = true;
        luaLib = true;
        nvimRuntime = true;
        plugins = true;
      };
      # fails due to conflicts with nvim-treesitter-grammars
      combinePlugins = {
        enable = false;
        standalonePlugins = [
          "blink.cmp"
          "nvim-treesitter"
        ];
      };
    };
  };
}
