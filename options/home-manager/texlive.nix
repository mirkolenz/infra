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
    name: preset: "sd -F 'preset=${name}' '${lib.concatStringsSep ", " (acronymPresetToList preset)}'"
  ) cfg.acronymPresets;

  bibtidyBase = "${lib.getExe pkgs.bibtex-tidy} --v2 --no-align --no-wrap --blank-lines --no-escape";
  bibtidyFilter = ''--omit="${lib.concatStringsSep "," cfg.bibtidyOmit}" --max-authors="${toString cfg.bibtidyMaxAuthors}"'';

  # Tidies the bibliography in a format, printing it or writing it to a directory with `output`.
  # bibtex-tidy ignores its input files whenever stdin is no terminal,
  # so the bibliography is always passed on stdin.
  mkBibScript =
    { output, full }:
    let
      verb = if output then "Copy" else "Print";
      fields = lib.optionalString full " with all fields but the abstract";
      filter = if full then "--omit=abstract" else bibtidyFilter;
      target = lib.optionalString output " --output=\"$argc_target_dir/references.bib\"";
    in
    lib.concatLines (
      [
        "# @describe ${verb} the tidied bibliography${fields}"
        "# @arg format=bibtex  Name of the bibliography file"
      ]
      ++ lib.optional output "# @arg target-dir=.  Directory receiving references.bib"
      ++ [
        ""
        ''${bibtidyBase} ${filter}${target} < "${cfg.bibliographyPath}/$argc_format.bib"''
      ]
    );

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
      target = "texmf";
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
      bibtidy.text = /* bash */ ''
        # @describe Tidy bibliographies with the managed bibtex-tidy settings
        # @arg args~ Arguments of bibtex-tidy

        ${bibtidyBase} ${bibtidyFilter} "$@"
      '';
      bibcat.text = mkBibScript {
        output = false;
        full = false;
      };
      bibcat-full.text = mkBibScript {
        output = false;
        full = true;
      };
      bibcopy.text = mkBibScript {
        output = true;
        full = false;
      };
      bibcopy-full.text = mkBibScript {
        output = true;
        full = true;
      };
      acrocat.text = /* bash */ ''
        # @describe Print the acronyms with the presets applied

        # shellcheck disable=SC2002 # the sd commands are generated via nix, so cat is more elegant than piping
        cat "${cfg.bibliographyPath}/acronyms.tex" | ${lib.concatStringsSep " | " acronymReplacements}
      '';
      acrocopy.text = /* bash */ ''
        # @describe Copy the acronyms with the presets applied
        # @arg target-dir=. Directory receiving acronyms.tex

        ${lib.getExe config.custom.commands.acrocat} > "$argc_target_dir/acronyms.tex"
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
