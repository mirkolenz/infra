{
  flake.modules.generic.languages =
    { config, pkgs, ... }:
    let
      settings = {
        formatting.command = [ config.custom.tools.nixfmt.command ];
        nixpkgs.expr = "import (builtins.getFlake \"nixpkgs\") { }";
      };
    in
    {
      custom = {
        languages.nix = {
          enable = true;
          files = [ "*.nix" ];
          editors.zed = {
            names = [ "Nix" ];
            extensions = [ "nix" ];
          };
          servers = [ "nixd" ];
          fixers = [ "nixf-diagnose" ];
          formatter = {
            server = "nixd";
            tool = "nixfmt";
          };
        };

        lsp.servers.nixd = {
          package = pkgs.nixd;
          settings.nixd = settings;
          # Zed's nix extension adds the section itself.
          editors.zed.settings = settings;
        };

        tools = {
          # The fixes of the lints that nixd reports in the editors.
          nixf-diagnose = {
            package = pkgs.nixf-diagnose;
            args = [
              "--auto-fix"
              "--variable-lookup=true"
              # unknown builtin `getFlake`
              "--ignore=sema-primop-unknown"
            ];
            # Exits with 1 while unfixable lints remain.
            editors.neovim.exitCodes = [
              0
              1
            ];
          };
          nixfmt = {
            package = pkgs.nixfmt-rs;
            stdinArgs = [ "-" ];
          };
        };
      };
    };
}
