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
          servers = [ "markdown-oxide" ];
          formatter.tool = "oxfmt";
        };

        lsp.servers.markdown-oxide = {
          package = pkgs.markdown-oxide;
          editors.zed.extension = "markdown-oxide";
        };
      };
    };
}
