{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages = {
          # keep-sorted start block=yes
          toml = {
            files = [ "*.toml" ];
            editors.zed = {
              names = [ "TOML" ];
              extensions = [ "toml" ];
            };
            servers = [ "tombi" ];
            formatter = {
              server = "tombi";
              tool = "tombi";
            };
          };
          xml = {
            files = [
              "*.svg"
              "*.xml"
              "*.xsd"
              "*.xsl"
              "*.xslt"
            ];
            editors = {
              neovim.names = [
                "xml"
                "xsd"
                "xsl"
                "xslt"
                "svg"
              ];
              zed = {
                names = [ "XML" ];
                extensions = [ "xml" ];
              };
            };
            servers = [ "lemminx" ];
            formatter.server = "lemminx";
          };
          yaml = {
            files = [
              "*.yaml"
              "*.yml"
            ];
            editors.zed.names = [ "YAML" ];
            servers = [ "yamlls" ];
            formatter.tool = "oxfmt";
          };
          # keep-sorted end
        };

        lsp.servers = {
          # keep-sorted start block=yes
          lemminx.package = pkgs.lemminx;
          tombi = {
            package = pkgs.tombi;
            args = [ "lsp" ];
            editors.zed.extension = "tombi";
          };
          yamlls = {
            package = pkgs.yaml-language-server;
            args = [ "--stdio" ];
            editors.zed.name = "yaml-language-server";
          };
          # keep-sorted end
        };

        tools.tombi = rec {
          package = pkgs.tombi;
          args = [ "format" ];
          stdinArgs = args ++ [
            "--stdin-filename"
            "{file}"
            "-"
          ];
        };
      };
    };
}
