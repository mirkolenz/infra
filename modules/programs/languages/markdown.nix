{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages.markdown = {
          files = [
            "*.markdown"
            "*.md"
          ];
          editors.zed.names = [ "Markdown" ];
          servers = [ "marksman" ];
          formatter.tool = "oxfmt";
        };

        lsp.servers.marksman = {
          package = pkgs.marksman;
          args = [ "server" ];
          editors.zed.extension = "marksman";
        };
      };
    };
}
