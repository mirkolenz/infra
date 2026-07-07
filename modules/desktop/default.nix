# General desktop defaults: NetworkManager, the default keyboard layout, and
# personal-workstation conveniences (Nix trust, nix-ld) for interactive machines.
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      # there is an issue with wpa_supplicant and broadcom-wl (used in Macs)
      networking.networkmanager = {
        enable = true;
        wifi.backend = "iwd";
      };

      # NetworkManager owns the interfaces here, so networkd manages nothing and
      # its wait-online times out and fails the rebuild.
      # NetworkManager-wait-online.service already gates network-online.target.
      systemd.network.wait-online.enable = false;

      nix.settings.trusted-users = [ "@wheel" ];

      programs.nix-ld.enable = true;

      # X server foundation shared by every desktop environment; each DE module
      # (cosmic/gnome/xfce) only adds its own session and display manager.
      services.xserver = {
        enable = true;
        excludePackages = with pkgs; [ xterm ];
      };
    };

  flake.modules.nixos.default =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      services.xserver.xkb = {
        layout = "us";
        options = "caps:escape";
      };

      # Apply the same XKB remapping to the virtual consoles (TTYs).
      console.useXkbConfig = true;

      users.users.${config.custom.user.login}.extraGroups = [ "networkmanager" ];
    };
}
