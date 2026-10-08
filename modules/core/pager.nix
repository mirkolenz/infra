let
  moorOptions = [
    "--quit-if-one-screen"
    "--no-clear-on-exit"
  ];
  # Linux-only: run systemd's pager (journalctl, systemctl) in secure mode so it
  # cannot spawn a shell or editor. SYSTEMD_PAGER is left unset on purpose, as
  # systemd falls back to PAGER (moor).
  systemdVariables = {
    SYSTEMD_PAGERSECURE = 1;
  };
  # NixOS and nix-darwin have no programs.moor, so configure it directly.
  system =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        moor
        lnav
      ];
      environment.variables = {
        PAGER = "moor";
        MOOR = toString moorOptions;
      };
    };
in
{
  flake.modules.nixos.base = {
    imports = [ system ];
    programs.less.enable = true;
    environment.variables = systemdVariables;
  };
  flake.modules.homeManager.linux =
    { lib, pkgs, ... }:
    {
      home.sessionVariables = systemdVariables;
      # The host's journalctl, pinning systemd would add it to standalone homes.
      custom.commands.jlog.text = /* bash */ ''
        # @describe Browse the systemd journal in lnav
        # @arg args~ Arguments of journalctl

        journalctl -a -o json "$@" | ${lib.getExe pkgs.lnav}
      '';
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
      home.packages = with pkgs; [
        lnav
        less
      ];
      programs.moor = {
        enable = true;
        options = moorOptions;
      };
    };
}
