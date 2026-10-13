{
  flake.modules.nixvim.default = {
    # vim.loader caches the bytecode of every required Lua module at runtime.
    luaLoader.enable = true;
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
      # Experimental upstream, and the pack collides on files that several plugins
      # ship, e.g. queries/markdown/injections.scm (snacks and the treesitter
      # queries) and doc/recipes.md (conform and oil).
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
