{
  flake.modules.nixvim.default = {
    plugins.oil = {
      enable = true;
      settings = {
        default_file_explorer = false;
        delete_to_trash = true;
      };
    };
  };
}
