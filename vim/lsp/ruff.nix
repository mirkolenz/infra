{ pkgs, ... }:
{
  lsp.servers.ruff = {
    enable = true;
    package = pkgs.ruff-bin;
  };
}
