{
  flake.modules.nixvim.default =
    { lib, pkgs, ... }:
    {
      lsp.servers.bashls = {
        enable = true;
        # bashls implements formatting by shelling out to shfmt, which it looks
        # up on $PATH by default. The indent width is not configurable here: it
        # comes from the editor via the LSP formatting options, i.e. shiftwidth.
        config.settings.bashIde.shfmt.path = lib.getExe pkgs.shfmt;
      };
    };
}
