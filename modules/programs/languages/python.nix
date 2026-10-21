{
  flake.modules.generic.languages =
    { pkgs, ... }:
    let
      # The lints of ruff and their fixes, with the rules in `select`.
      ruffFix =
        {
          select ? [ ],
          codeAction,
        }:
        let
          args = [
            "check"
            "--fix"
            "--force-exclude"
            "--no-cache"
          ]
          ++ map (rule: "--select=${rule}") select;
        in
        {
          package = pkgs.ruff-bin;
          inherit args;
          stdinArgs = args ++ [
            "--stdin-filename"
            "{file}"
            "-"
          ];
          editors = {
            zed.codeAction = codeAction;
            # Exits with 1 while unfixable lints remain.
            neovim.exitCodes = [
              0
              1
            ];
          };
        };
      tySettings.diagnosticMode = "workspace";
    in
    {
      custom = {
        # ty provides the language features, ruff the lints and the formatting.
        languages.python = {
          enable = true;
          files = [
            "*.py"
            "*.pyi"
          ];
          editors.zed.names = [ "Python" ];
          servers = [
            "ty"
            "ruff"
          ];
          fixers = [
            "ruff_fix"
            "ruff_organize_imports"
          ];
          formatter = {
            server = "ruff";
            tool = "ruff_format";
          };
        };

        lsp.servers = {
          ruff = {
            package = pkgs.ruff-bin;
            args = [ "server" ];
            linter = true;
          };
          ty = {
            package = pkgs.ty-bin;
            args = [ "server" ];
            settings.ty = tySettings;
            # Zed adds the section itself.
            editors.zed.settings = tySettings;
          };
        };

        tools = {
          ruff_fix = ruffFix { codeAction = "source.fixAll.ruff"; };
          ruff_organize_imports = ruffFix {
            select = [ "I001" ];
            codeAction = "source.organizeImports.ruff";
          };
          ruff_format = rec {
            package = pkgs.ruff-bin;
            args = [
              "format"
              "--force-exclude"
              "--no-cache"
            ];
            stdinArgs = args ++ [
              "--stdin-filename"
              "{file}"
              "-"
            ];
          };
        };
      };
    };
}
