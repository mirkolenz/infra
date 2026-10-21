{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages.typst = {
          files = [ "*.typ" ];
          editors.zed = {
            names = [ "Typst" ];
            extensions = [ "typst" ];
          };
          servers = [ "tinymist" ];
          # tinymist bundles its own typstyle, whose version can differ from the one of treefmt.
          formatter.tool = "typstyle";
        };

        # tinymist reads its settings without a section.
        lsp.servers.tinymist = {
          package = pkgs.tinymist;
          args = [ "lsp" ];
          settings = {
            exportPdf = "never";
            outputPath = "$root/$name";
          };
        };

        # 120 columns wide, like tinymist.
        tools.typstyle = {
          package = pkgs.typstyle;
          args = [
            "--column"
            "120"
            "-i"
          ];
          stdinArgs = [
            "--column"
            "120"
          ];
        };
      };
    };
}
