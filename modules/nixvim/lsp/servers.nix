# The servers themselves come from the shared registry, see options/nixvim/editors.nix.
{
  flake.modules.nixvim = {
    default = {
      plugins.lspconfig.enable = true;
      lsp.inlayHints.enable = true;
    };
    extras = {
      # json and yaml schemas for jsonls and yamlls
      plugins.schemastore.enable = true;
    };
  };
}
