# Cross-cutting feature flags, shared across all module systems
# (nixos/darwin/home/nixvim). Values are set per host/configuration; home inherits
# them from the host in modules/core/home.nix, and nixvim inherits extras.enable in
# modules/programs/neovim.nix.
{ lib, config, ... }:
{
  options.custom.features = {
    unattended.enable = lib.mkEnableOption "unattended operation (always-on host: no sleep, auto-upgrade)";
    extras.enable = lib.mkEnableOption "extra packages beyond the base set";
    graphical = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.custom.features.graphical.desktopManager != null;
        description = ''
          Whether this host has a graphical session (GUI apps, fonts, audio).
          Defaults to true when a desktop manager is selected; set explicitly on
          hosts that have a display but no NixOS-managed desktop (e.g. darwin).
        '';
      };
      desktopManager = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "cosmic"
            "gnome"
            "xfce"
          ]
        );
        default = null;
        description = ''
          Desktop environment to configure when graphical.enable is on.
          null means no desktop environment is managed here (e.g. standalone
          home-manager on a foreign distro): graphical apps are still installed,
          but the session itself is left to the host.
        '';
      };
    };
  };
}
