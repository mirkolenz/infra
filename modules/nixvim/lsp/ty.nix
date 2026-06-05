{
  flake.modules.nixvim.default =
    { pkgs, ... }:
    {
      lsp.servers.ty = {
        enable = true;
        package = pkgs.ty-bin;
        config.settings = {
          diagnosticMode = "workspace";
        };
      };
    };
}
