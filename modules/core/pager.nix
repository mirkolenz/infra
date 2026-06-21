let
  packages =
    pkgs: with pkgs; [
      moor
      lnav
    ];
  variables = {
    PAGER = "moor";
    MOOR = toString [
      "--quit-if-one-screen"
      "--no-clear-on-exit"
    ];
  };
  system =
    { pkgs, ... }:
    {
      environment.systemPackages = packages pkgs;
      environment.variables = variables;
    };
in
{
  flake.modules.nixos.base = {
    imports = [ system ];
    programs.less.enable = true;
  };
  flake.modules.darwin.base = system;
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      home.packages = packages pkgs;
      home.sessionVariables = variables;
    };
}
