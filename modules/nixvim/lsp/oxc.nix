{
  flake.modules.nixvim.default = {
    lsp.servers.oxlint = {
      enable = true;
      config.initialization_options.settings = {
        run = "onType";
        typeAware = true;
      };
    };
    lsp.servers.oxfmt = {
      enable = true;
      config.initialization_options.settings = {
        run = "onSave";
      };
    };
  };
}
