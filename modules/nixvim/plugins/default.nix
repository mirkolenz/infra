{
  flake.modules.nixvim.default = {
    plugins = {
      diffview.enable = true;
      flash.enable = true;
      git-conflict.enable = true;
      gitignore.enable = true;
      gitsigns.enable = true;
      grug-far.enable = true;
      neogit.enable = true;
      nvim-autopairs.enable = true;
      persistence.enable = true;
      quicker.enable = true;
      schemastore.enable = true;
      web-devicons.enable = true;
    };
  };
}
