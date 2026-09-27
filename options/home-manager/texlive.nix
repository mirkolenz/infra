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
  bibOutput = ''--output="''${2:-.}/references.bib"'';

  # Tidies the bibliography in format `$1`, which defaults to bibtex.
  # bibtex-tidy ignores its input files whenever stdin is no terminal,
  # so the bibliography is always passed on stdin.
  mkBibScript = args: ''${bibtidyBase} ${args} < "${cfg.bibliographyPath}/''${1:-bibtex}.bib"'';

  cmdTexts = {
    texmfup = lib'.mkVendorScript {
      source = cfg.texmfPath;
      target = "texmf";
    };
    latexmkrc = /* bash */ ''
      targetFile="''${1:-.latexmkrc}"
      exec cp --force --no-preserve=all ${config.home.file.".latexmkrc".source} "$targetFile"
    '';
    bibtidy = ''${bibtidyBase} ${bibtidyFilter} "$@"'';
    bibcat = mkBibScript bibtidyFilter;
    bibcat-full = mkBibScript "--omit=abstract";
    bibcopy = mkBibScript "${bibtidyFilter} ${bibOutput}";
    bibcopy-full = mkBibScript "--omit=abstract ${bibOutput}";
    acrocat = /* bash */ ''
      # shellcheck disable=SC2002 # the sd commands are generated via nix, so cat is more elegant than piping
      cat "${cfg.bibliographyPath}/acronyms.tex" | ${lib.concatStringsSep " | " acronymReplacements}
    '';
    acrocopy = /* bash */ ''
      targetDir="''${1:-.}"
      ${lib.getExe cmds.acrocat} > "$targetDir/acronyms.tex"
    '';
  };

  cmds = lib.mapAttrs (name: text: pkgs.writeShellApplication { inherit name text; }) cmdTexts;
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
    home = {
      activation.linkTexmf = lib'.mkCheckoutLink {
        inherit config;
        target = "${config.home.homeDirectory}/texmf";
        checkout = cfg.texmfPath;
      };
      packages = [ cfg.package ] ++ lib.attrValues cmds;
      file = {
        ".latexmkrc".source = pkgs.writeText "latexmkrc" cfg.latexmkrc;
      };
    };
  };
}
