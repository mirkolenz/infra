{
  flake.modules.nixvim = {
    default = {
      plugins.lspconfig.enable = true;
      lsp.inlayHints.enable = true;
    };
    extras = {
      # json and yaml schemas for jsonls and yamlls
      plugins.schemastore.enable = true;
      lsp.servers = {
        # keep-sorted start
        astro.enable = true;
        buf_ls.enable = true;
        cssls.enable = true;
        docker_language_server.enable = true;
        gopls.enable = true;
        html.enable = true;
        jdtls.enable = true;
        jsonls.enable = true;
        lemminx.enable = true;
        marksman.enable = true;
        phpactor.enable = true;
        tailwindcss.enable = true;
        tombi.enable = true;
        tsc.enable = true;
        yamlls.enable = true;
        # keep-sorted end
      };
    };
  };
}
