{
  flake.modules.nixvim.default = {
    lsp.servers.texlab = {
      enable = true;
      config.settings.texlab = {
        bibtexFormatter = "tex-fmt";
        latexFormatter = "tex-fmt";
        inlayHints = {
          labelDefinitions = false;
          labelReferences = false;
          maxLength = 32;
        };
        # Build explicitly via <leader>tb; preview the PDF inline with snacks.image
        # (see documents.nix) instead of forwarding to an external GUI viewer.
        build.onSave = false;
      };
    };
  };
}
