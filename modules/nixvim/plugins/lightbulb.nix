{
  flake.modules.nixvim.default = {
    plugins.nvim-lightbulb = {
      enable = true;
      settings = {
        autocmd.enabled = true;
      };
    };
  };
}
