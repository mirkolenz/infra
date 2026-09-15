{
  flake.modules.nixvim.default = {
    # Formatting is handled by conform.nvim (see ../plugins/conform.nix); oxlint
    # stays a server for its on-type diagnostics.
    lsp.servers.oxlint = {
      enable = true;
      config.initialization_options.settings = {
        run = "onType";
        typeAware = true;
      };
    };
  };
}
