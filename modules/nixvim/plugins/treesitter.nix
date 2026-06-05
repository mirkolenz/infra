{
  flake.modules.nixvim.default = {
    plugins.treesitter = {
      enable = true;
      folding.enable = true;
      highlight.enable = true;
      indent.enable = true;
    };
    plugins.treesitter-textobjects = {
      enable = true;
      settings = {
        lsp_interop.enable = true;
        move.enable = true;
        select.enable = true;
        swap.enable = true;
      };
    };
  };
}
