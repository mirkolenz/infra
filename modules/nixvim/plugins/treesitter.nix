{
  flake.modules.nixvim.default = {
    plugins.treesitter = {
      enable = true;
      folding.enable = true;
      highlight.enable = true;
      indent.enable = true;
    };
  };
}
