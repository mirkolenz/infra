{
  flake.modules.nixvim.default = {
    plugins.lspconfig.enable = true;
    lsp = {
      inlayHints.enable = true;
      servers = {
        # keep-sorted start
        astro.enable = true;
        bashls.enable = true;
        buf_ls.enable = true;
        copilot.enable = true;
        cssls.enable = true;
        docker_language_server.enable = true;
        gopls.enable = true;
        java_language_server.enable = true;
        lemminx.enable = true;
        tailwindcss.enable = true;
        tombi.enable = true;
        tsgo.enable = true;
        yamlls.enable = true;
        # keep-sorted end
      };
    };
  };
}
