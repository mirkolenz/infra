# General desktop defaults: NetworkManager, the default keyboard layout, and
# personal-workstation conveniences (nix-ld) for interactive machines.
{
  flake.modules.nixos.base =
    { lib, config, ... }:
    lib.mkIf config.custom.features.graphical.enable {
      # wpa_supplicant 2.11 offloads the four-way handshake to the firmware,
      # which the Broadcom chips of Macs fail.
      # https://wiki.t2linux.org/guides/wifi-bluetooth/
      networking.networkmanager = {
        enable = true;
        wifi.backend = "iwd";
      };

      # NetworkManager owns the interfaces here, so networkd manages nothing and
      # its wait-online times out and fails the rebuild.
      # NetworkManager-wait-online.service already gates network-online.target.
      systemd.network.wait-online.enable = false;

      programs.nix-ld.enable = true;
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
