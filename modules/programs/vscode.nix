{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (pkgs.stdenv.isLinux && config.custom.features.graphical.enable) {
      programs.vscode = {
        enable = true;
        package = pkgs.vscode;
      };
    };
}
