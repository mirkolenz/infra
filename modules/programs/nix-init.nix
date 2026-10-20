{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    lib.mkIf config.custom.features.extras.enable {
      programs.nix-init = {
        enable = true;
        settings = {
          maintainers = [ "mirkolenz" ];
          nixpkgs = "builtins.getFlake \"nixpkgs\"";
          commit = false;
        };
      };
    };
}
