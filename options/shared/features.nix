# Cross-cutting feature flags, shared across all module systems
# (nixos/darwin/home/nixvim). Values are set per host/configuration; home inherits
# them from the host in modules/core/home.nix, and nixvim inherits withOptionals in
# modules/programs/neovim.nix.
{ lib, ... }:
{
  options.custom.features = {
    withAlwaysOn = lib.mkEnableOption "always on";
    withOptionals = lib.mkEnableOption "all packages";
    withDisplay = lib.mkEnableOption "display";
    desktop = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "cosmic"
          "gnome"
          "xfce"
        ]
      );
      default = null;
      description = ''
        Desktop environment to configure when withDisplay is enabled.
        null means no desktop environment is managed here (e.g. standalone
        home-manager on a foreign distro): graphical apps are still installed,
        but the session itself is left to the host.
      '';
    };
  };
}
