{
  flake.modules.generic.languages =
    { pkgs, config, ... }:
    {
      custom = {
        languages.php = {
          files = [ "*.php" ];
          editors.zed = {
            names = [ "PHP" ];
            extensions = [ "php" ];
          };
          servers = [ "phpactor" ];
          formatter.tool = if config.custom.features.lowMemory.enable then null else "mago_format";
        };

        lsp.servers.phpactor = {
          package = pkgs.phpactor;
          args = [ "language-server" ];
        };

        tools.mago_format = rec {
          package = pkgs.mago;
          args = [ "format" ];
          stdinArgs = args ++ [ "--stdin-input" ];
        };
      };
    };
}
