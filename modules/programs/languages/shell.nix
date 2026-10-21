{
  flake.modules.generic.languages =
    { config, pkgs, ... }:
    {
      custom = {
        languages.shellscript = {
          files = [
            "*.bash"
            "*.sh"
          ];
          editors = {
            neovim.names = [
              "sh"
              "bash"
            ];
            zed.names = [ "Shell Script" ];
            fresh.names = [ "bash" ];
          };
          servers = [ "bashls" ];
          formatter = {
            server = "bashls";
            tool = "shfmt";
          };
        };

        lsp.servers.bashls = {
          package = pkgs.bash-language-server;
          args = [ "start" ];
          # The indent width comes from the editor via the LSP formatting options.
          settings.bashIde.shfmt.path = config.custom.tools.shfmt.command;
          editors.zed.name = "bash-language-server";
        };

        # The editors pass their indentation of two spaces.
        tools.shfmt = {
          package = pkgs.shfmt;
          args = [
            "-i"
            "2"
            "-w"
          ];
          stdinArgs = [
            "-i"
            "2"
            "--filename"
            "{file}"
          ];
        };
      };
    };
}
