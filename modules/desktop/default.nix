# General desktop defaults: NetworkManager, the default keyboard layout, and
# personal-workstation conveniences (nix-ld) for interactive machines.
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
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      services.xserver.xkb = {
        layout = "us";
        options = "caps:escape";
      };

      # Apply the same XKB remapping to the virtual consoles (TTYs).
      console.useXkbConfig = true;

      # Import and manage VPN configs from the desktop network settings.
      # WireGuard needs no plugin, NetworkManager supports it natively.
      # https://networkmanager.dev/docs/vpn/
      networking.networkmanager.plugins = with pkgs; [
        networkmanager-openvpn
      ];

      users.users.${config.custom.user.login}.extraGroups = [ "networkmanager" ];
    };
}
