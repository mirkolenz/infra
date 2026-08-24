{
  flake.modules.homeManager.default =
    { pkgs, ... }:
    {
      programs.fresh-editor = {
        enable = true;
        package = pkgs.fresh-editor-bin;
        settings = { };
      };
    };
}
