let
  gopls = {
    servers = [ "gopls" ];
    formatter.server = "gopls";
  };
in
{
  flake.modules.generic.languages =
    { lib, pkgs, ... }:
    {
      custom = {
        languages = {
          go = {
            imports = [ gopls ];
            files = [ "*.go" ];
            editors.zed.names = [ "Go" ];
            formatter.tool = "gofmt";
          };
          gomod = {
            imports = [ gopls ];
            files = [ "go.mod" ];
            editors.zed.names = [ "Go Mod" ];
          };
          gotmpl = gopls;
          gowork = {
            imports = [ gopls ];
            files = [ "go.work" ];
            editors.zed.names = [ "Go Work" ];
          };
        };

        lsp.servers.gopls.package = pkgs.gopls;

        tools.gofmt = {
          package = pkgs.go;
          command = lib.getExe' pkgs.go "gofmt";
          args = [ "-w" ];
          stdinArgs = [ ];
        };
      };
    };
}
