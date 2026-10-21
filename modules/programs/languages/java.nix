{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages.java = {
          files = [ "*.java" ];
          editors.zed = {
            names = [ "Java" ];
            extensions = [ "java" ];
          };
          servers = [ "jdtls" ];
          formatter.server = "jdtls";
        };

        lsp.servers.jdtls = {
          package = pkgs.jdt-language-server;
          # nvim-lspconfig passes a data directory per project, finding jdtls on the PATH of nixvim.
          editors.neovim.config.cmd = null;
        };
      };
    };
}
