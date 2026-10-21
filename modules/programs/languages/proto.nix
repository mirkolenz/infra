{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages.proto = {
          files = [ "*.proto" ];
          editors = {
            zed = {
              names = [ "Proto" ];
              extensions = [ "proto" ];
            };
            fresh.names = [ "protobuf" ];
          };
          servers = [ "buf_ls" ];
          formatter = {
            server = "buf_ls";
            tool = "buf";
          };
        };

        lsp.servers.buf_ls = {
          package = pkgs.buf;
          args = [
            "lsp"
            "serve"
            "--log-format=text"
          ];
          editors.zed.name = "buf";
        };

        tools.buf = {
          package = pkgs.buf;
          args = [
            "format"
            "-w"
          ];
        };
      };
    };
}
