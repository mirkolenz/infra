{
  config,
  lib,
  lib',
  pkgs,
  ...
}:
let
  cfg = config.custom.texlive;

  acronymPresetToList = lib.mapAttrsToList (name: value: "${name}=${value}");
  acronymReplacements = lib.mapAttrsToList (
    name: preset:
    "${lib.getExe pkgs.sd} -F 'preset=${name}' '${lib.concatStringsSep ", " (acronymPresetToList preset)}'"
  ) cfg.acronymPresets;

  bibtidy = "${lib.getExe pkgs.bibtex-tidy} --v2 --no-align --no-wrap --blank-lines --no-escape";
  bibtidyFilter = lib.escapeShellArgs [
    "--omit=${lib.concatStringsSep "," cfg.bibtidyOmit}"
    "--max-authors=${toString cfg.bibtidyMaxAuthors}"
  ];

  latexmkrcFile = pkgs.writeText "latexmkrc" cfg.latexmkrc;
in
{
  options = {
    # https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/texlive.section.md
    custom.texlive = {
      enable = lib.mkEnableOption "TeX Live";

      package = lib.mkPackageOption pkgs "TeX Live Scheme" {
        default = [ "texliveFull" ];
        example = "pkgs.texliveSmall";
      };

      bibliographyPath = lib.mkOption {
        type = lib.types.str;
        default = "${config.custom.projectsPath}/mirkolenz/bibliography";
        description = "Location of the bibliography checkout.";
      };

      texmfPath = lib.mkOption {
        type = lib.types.str;
        default = "${config.custom.projectsPath}/mirkolenz/texmf";
        description = "Location of the texmf checkout, linked to ~/texmf, the default TEXMFHOME.";
      };

      latexmkrc = lib.mkOption {
        type = lib.types.lines;
        description = "Content of the .latexmkrc file.";
      };

      acronymPresets = lib.mkOption {
        type = with lib.types; attrsOf (attrsOf str);
        description = "Acronym presets to use.";
        default = { };
      };

      bibtidyMaxAuthors = lib.mkOption {
        type = lib.types.int;
        description = "Maximum number of authors to display.";
        default = 10;
      };

      bibtidyOmit = lib.mkOption {
        type = with lib.types; listOf str;
        description = "Fields to omit from the bibliography.";
        default = [
          "abstract"
          "address"
          "annotation"
          "archiveprefix"
          "chapter"
          "copyright"
          "doi"
          "edition"
          "editor"
          "eprint"
          "googlebooks"
          "isbn"
          "issn"
          "langid"
          "language"
          "lccn"
          "month"
          "number"
          "pmcid"
          "pmid"
          "primaryclass"
          "series"
          "url"
          "urldate"
          "volume"
          # "eprinttype"
          # "pages"
          # "publisher"
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    custom.vendor.texmf = {
      source = cfg.texmfPath;
      target = "vendor/texmf";
      projectFile = {
        name = ".latexmkrc";
        source = latexmkrcFile;
      };
    };
    custom.commands = {
      latexmkrc.text = /* bash */ ''
        # @describe Copy the managed .latexmkrc into the current project
        # @arg target-file=.latexmkrc

        exec cp --force --no-preserve=all ${latexmkrcFile} "$argc_target_file"
      '';
      # bibtex-tidy ignores its input files whenever stdin is no terminal,
      # so the bibliography is always passed on stdin.
      bib.text = /* bash */ ''
        # @describe Tidy and print the managed bibliography and acronyms

        # @cmd Tidy bibliographies with the managed bibtex-tidy settings
        # @arg args~ Arguments of bibtex-tidy
        tidy() {
          exec ${bibtidy} ${bibtidyFilter} "''${argc_args[@]}"
        }

        # @cmd Print the tidied bibliography
        # @flag -f --full                Keep all fields but the abstract
        # @option -o --output-dir <DIR>  Write references.bib into a directory instead
        # @arg format[=bibtex|biblatex]  Name of the bibliography file
        references() {
          filter=(${bibtidyFilter})

          if [ -n "$argc_full" ]; then
            filter=(--omit=abstract)
          fi

          if [ -n "$argc_output_dir" ]; then
            exec > "$argc_output_dir/references.bib"
          fi

          ${bibtidy} "''${filter[@]}" < "${cfg.bibliographyPath}/$argc_format.bib"
        }

        # @cmd Print the acronyms with the presets applied
        # @option -o --output-dir <DIR>  Write acronyms.tex into a directory instead
        acronyms() {
          if [ -n "$argc_output_dir" ]; then
            exec > "$argc_output_dir/acronyms.tex"
          fi

          # shellcheck disable=SC2002 # the sd commands are generated via nix, so cat is more elegant than piping
          cat "${cfg.bibliographyPath}/acronyms.tex"${
            lib.concatMapStrings (sd: " | ${sd}") acronymReplacements
          }
        }
      '';
    };
    home = {
      activation.linkTexmf = lib'.mkCheckoutLink {
        inherit config;
        target = "${config.home.homeDirectory}/texmf";
        checkout = cfg.texmfPath;
      };
      packages = [ cfg.package ];
      file = {
        ".latexmkrc".source = latexmkrcFile;
      };
    };
  };
}
