{
  flake.modules.nixvim.default = {
    plugins.wrapping = {
      enable = false;
      settings = {
        softener = {
          gitcommit = true;
        };
      };
    };
  };
}
