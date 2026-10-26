{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages.sql = {
          files = [ "*.sql" ];
          editors.zed = {
            names = [ "SQL" ];
            extensions = [ "sql" ];
          };
          servers = [ "sqruff" ];
          formatter = {
            server = "sqruff";
            tool = "sqruff";
          };
        };

        lsp.servers.sqruff = {
          package = pkgs.sqruff;
          args = [ "lsp" ];
          editors.zed.enable = false;
        };

        tools.sqruff = rec {
          package = pkgs.sqruff;
          args = [ "fix" ];
          stdinArgs = args ++ [ "-" ];
          # Exits with 1 while unfixable lints remain.
          editors.neovim.exitCodes = [
            0
            1
          ];
        };
      };
    };
}
