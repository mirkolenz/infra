{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    # https://tug.org/texlive/scripts-sys-user.html
    lib.mkIf config.custom.features.extras.enable {
      custom.texlive = {
        enable = true;
        bibliographyPath = "${config.custom.projectsPath}/mirkolenz/bibliography";
        texmfPath = "${config.home.homeDirectory}/texmf";
        latexmkrc = /* perl */ ''
          # 1: pdflatex
          # 4: lualatex
          $pdf_mode = 1;

          @default_files = ("main.tex");

          # add `-shell-escape` if needed
          $pdflatex = "pdflatex %O %S";
          $lualatex = "lualatex %O %S";

          # inject local texmf if needed
          # ensure_path("TEXINPUTS", "./texmf//");
          # ensure_path("BSTINPUTS", "./texmf//");
          # ensure_path("BIBINPUTS", "./texmf//");

          # set timezone
          $ENV{"TZ"} = "Europe/Berlin";

          # force compilation
          $go_mode = 3;

          # force bibtex
          $bibtex_use = 2;

          # No previewer, mirroring the typst setup: run `tdf main.pdf` in a second
          # pane, it reloads whenever latexmk rewrites the PDF.
          $view = 'none';
        '';
        acronymPresets = {
          short = {
            first-style = "short";
            long = "{}";
            class = "short";
          };
          long = {
            first-style = "long";
            class = "long";
          };
        };
      };
      home.packages = with pkgs; [
        arxiv-latex-cleaner
        bibtex-tidy
        bibtexbrowser.bibtex2cff
        ltex-ls-plus
        tectonic
      ];
    };
}
