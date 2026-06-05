{
  flake.modules.nixvim.default = {
    plugins.snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        bufdelete.enabled = true;
        debug.enabled = true;
        explorer = {
          enabled = true;
          replace_netrw = false;
        };
        gh.enabled = true;
        git.enabled = true;
        gitbrowse.enabled = true;
        image.enabled = true;
        indent.enabled = true;
        input.enabled = true;
        lazygit = {
          enabled = false;
          configure = false;
        };
        notifier = {
          enabled = true;
          timeout = 5000;
        };
        picker.enabled = true;
        quickfile.enabled = true;
        rename.enabled = true;
        scope.enabled = true;
        scratch.enabled = false;
        scroll.enabled = false;
        terminal.enabled = true;
        toggle.enabled = true;
        words.enabled = true;
        zen.enabled = false;
      };
    };
  };
}
