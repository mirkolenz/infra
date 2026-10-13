{
  flake.modules.nixvim.default = {
    plugins = {
      blink-pairs.enable = true;
      flash.enable = true;
      git-conflict.enable = true;
      gitignore.enable = true;
      gitsigns.enable = true;
      grug-far.enable = true;
      mini-icons = {
        enable = true;
        # Plugins that only know nvim-web-devicons, e.g. lualine, get mini.icons too.
        mockDevIcons = true;
      };
      persistence.enable = true;
      quicker.enable = true;
      schemastore.enable = true;
    };
  };
}
