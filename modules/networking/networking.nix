# Networking: base networkd/firewall (all hosts) + tailscale (full systems).
{
  flake.modules.nixos.base =
    { lib, ... }:
    {
      networking = {
        useNetworkd = true;
        # this is overridden by NetworkManager on gui machines
        useDHCP = lib.mkDefault true;
        # this is not compatible with networkd
        useHostResolvConf = false;
        nftables.enable = true;
        firewall.enable = lib.mkDefault true;
      };

      # Do not manage wifi interfaces with networkd by default
      systemd.network.networks."90-wlan" = {
        matchConfig.Type = "wlan";
        linkConfig.Unmanaged = true;
      };
    };

  flake.modules.nixos.default =
    { lib, config, ... }:
    {
      systemd.network.wait-online = {
        timeout = 30;
      };

      services.tailscale = {
        enable = true;
        openFirewall = true;
      };

      # Exit nodes / subnet routers forward traffic over asymmetric paths, which
      # strict reverse-path filtering drops once the firewall is enabled. The
      # upstream module only relaxes this for client/both, so cover server here.
      networking.firewall.checkReversePath = lib.mkIf (
        config.services.tailscale.useRoutingFeatures == "server"
      ) "loose";
    };
}
