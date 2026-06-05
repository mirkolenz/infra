{
  flake.modules.nixvim.default = {
    colorscheme = "gruvbox";
    colorschemes = {
      gruvbox = {
        enable = true;
        settings = {
          contrast = "hard";
        };
      };
      github-theme.enable = false;
      monokai-pro = {
        enable = false;
        settings = {
          filter = "spectrum";
        };
      };
      catppuccin = {
        enable = false;
        settings = {
          background = {
            light = "latte";
            dark = "mocha";
          };
        };
      };
    };
  };
}
