# Networking: one network manager per host and the firewall (all hosts) + tailscale (full systems).
{
  flake.modules.nixos.base =
    { lib, config, ... }:
    {
      networking = {
        # A host runs only one network manager, so networkd steps aside for NetworkManager.
        useNetworkd = !config.networking.networkmanager.enable;
        nftables.enable = true;
      };

      # networkd only enables it by default
      services.resolved.enable = lib.mkDefault true;
    };

  flake.modules.nixos.default = {
    systemd.network.wait-online = {
      timeout = 30;
    };

    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
