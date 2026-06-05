{
  flake.modules.nixvim.default =
    { pkgs, ... }:
    {
      lsp.servers.ruff = {
        enable = true;
        package = pkgs.ruff-bin;
      };
    };
}
