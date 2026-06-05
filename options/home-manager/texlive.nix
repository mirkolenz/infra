{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.custom.texlive;

  acronymPresetToList = lib.mapAttrsToList (name: value: "${name}=${value}");
  acronymReplacements = lib.mapAttrsToList (
    name: preset: "sd -F 'preset=${name}' '${lib.concatStringsSep ", " (acronymPresetToList preset)}'"
  ) cfg.acronymPresets;

  cmdTexts = {
    texmfup = /* bash */ ''
      targetDir="''${1:-texmf}"
      rm -rf "$targetDir"
      cp -r --no-preserve=all ${cfg.texmfPath} "$targetDir"
    '';
    latexmkrc = /* bash */ ''
      targetFile="''${1:-.latexmkrc}"
      exec cp --force --no-preserve=all ${config.home.file.".latexmkrc".source} "$targetFile"
    '';
    bibtidy = /* bash */ ''
      ${lib.getExe pkgs.bibtex-tidy} --v2 \
        --no-align --no-wrap --blank-lines --no-escape \
        --omit="${lib.concatStringsSep "," cfg.bibtidyOmit}" \
        --max-authors="${toString cfg.bibtidyMaxAuthors}" \
        "$@"
    '';
    bibcat = /* bash */ ''
      format="''${1:-bibtex}"
      ${lib.getExe cmds.bibtidy} "${cfg.bibliographyPath}/$format.bib"
    '';
    bibcat-full = /* bash */ ''
      format="''${1:-bibtex}"
      ${lib.getExe pkgs.bibtex-tidy} --v2 \
        --no-align --no-wrap --blank-lines --no-escape \
        --omit="abstract" \
        "${cfg.bibliographyPath}/$format.bib"
    '';
    bibcopy = /* bash */ ''
      format="''${1:-bibtex}"
      targetDir="''${2:-.}"
      ${lib.getExe cmds.bibtidy} --output="$targetDir/references.bib" "${cfg.bibliographyPath}/$format.bib"
    '';
    bibcopy-full = /* bash */ ''
      format="''${1:-bibtex}"
      targetDir="''${2:-.}"
      ${lib.getExe pkgs.bibtex-tidy} --v2 \
        --no-align --no-wrap --blank-lines --no-escape \
        --omit="abstract" \
        --output="$targetDir/references.bib" \
        "${cfg.bibliographyPath}/$format.bib"
    '';
    acrocat = /* bash */ ''
      # shellcheck disable=SC2002 # the sd commands are generated via nix, so cat is more elegant than piping
      cat "${cfg.bibliographyPath}/acronyms.tex" | ${lib.concatStringsSep " | " acronymReplacements}
    '';
    acrocopy = /* bash */ ''
      targetDir="''${1:-.}"
      ${lib.getExe cmds.acrocat} "${cfg.bibliographyPath}" > "$targetDir/acronyms.tex"
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
        default = inputs.bibliography.outPath;
        description = "Location of the bibliography files.";
      };

      texmfPath = lib.mkOption {
        type = lib.types.str;
        default = inputs.texmf.outPath;
        description = "Location of the texmf files.";
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
      packages = [ cfg.package ] ++ (lib.optionals (cfg.bibliographyPath != "") (lib.attrValues cmds));
      file = {
        ".latexmkrc".source = pkgs.writeText "latexmkrc" cfg.latexmkrc;
      };
    };
  };
}
