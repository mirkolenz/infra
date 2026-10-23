# Networking: base networkd/firewall (all hosts) + tailscale (full systems).
{
  flake.modules.nixos.base = {
    networking = {
      useNetworkd = true;
      # this is not compatible with networkd
      useHostResolvConf = false;
      nftables.enable = true;
    };

    # Do not manage wifi interfaces with networkd by default
    systemd.network.networks."90-wlan" = {
      matchConfig.Type = "wlan";
      linkConfig.Unmanaged = true;
    };
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
