let
  texlab = {
    servers = [ "texlab" ];
    # texlab only finds tex-fmt on the PATH, so the editors run it themselves.
    formatter.tool = "tex-fmt";
  };
in
{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages = {
          bibtex = {
            imports = [ texlab ];
            files = [ "*.bib" ];
            editors = {
              neovim.names = [ "bib" ];
              zed = {
                names = [ "BibTeX" ];
                extensions = [ "latex" ];
              };
            };
          };
          latex = {
            imports = [ texlab ];
            files = [
              "*.cls"
              "*.sty"
              "*.tex"
            ];
            editors = {
              neovim.names = [
                "tex"
                "plaintex"
              ];
              zed = {
                names = [ "LaTeX" ];
                extensions = [ "latex" ];
              };
            };
          };
        };

        lsp.servers.texlab = {
          package = pkgs.texlab;
          settings.texlab = {
            inlayHints = {
              labelDefinitions = false;
              labelReferences = false;
              maxLength = 32;
            };
            # Builds run on demand, and tdf, the PDF viewer, has no synctex support.
            build = {
              onSave = false;
              forwardSearchAfter = false;
            };
          };
        };

        tools.tex-fmt = {
          package = pkgs.tex-fmt;
          stdinArgs = [ "--stdin" ];
        };
      };
    };
}
