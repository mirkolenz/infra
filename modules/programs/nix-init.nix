{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.nix-init = {
        enable = true;
        settings = {
          maintainers = [ "mirkolenz" ];
          nixpkgs = "builtins.getFlake \"pkgs\"";
          commit = false;
        };
      };
    };
}
