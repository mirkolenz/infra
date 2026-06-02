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
}
