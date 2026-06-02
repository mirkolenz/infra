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
}
