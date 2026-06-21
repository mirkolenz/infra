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
  # Linux-only: run systemd's pager (journalctl, systemctl) in secure mode so it
  # cannot spawn a shell or editor. SYSTEMD_PAGER is left unset on purpose, as
  # systemd falls back to PAGER (moor).
  systemdVariables = {
    SYSTEMD_PAGERSECURE = 1;
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
    environment.variables = systemdVariables;
  };
  flake.modules.homeManager.linux = {
    home.sessionVariables = systemdVariables;
  };
  # programs.less is NixOS-only, so install the package directly elsewhere.
  flake.modules.darwin.base =
    { pkgs, ... }:
    {
      imports = [ system ];
      environment.systemPackages = [ pkgs.less ];
    };
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      home.packages = packages pkgs ++ [ pkgs.less ];
      home.sessionVariables = variables;
    };
}
