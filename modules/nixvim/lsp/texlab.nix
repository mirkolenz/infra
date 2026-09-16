{
  flake.modules.nixvim.default = {
    lsp.servers.texlab = {
      enable = true;
      config.settings.texlab = {
        inlayHints = {
          labelDefinitions = false;
          labelReferences = false;
          maxLength = 32;
        };
        # Build explicitly via <leader>tb; preview the PDF inline with vim.ui.img
        # (see ../lua/pdf-preview.lua) instead of forwarding to a GUI viewer.
        build.onSave = false;
      };
    };
  };
}
