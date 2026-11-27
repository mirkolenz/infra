# Failed services of all full systems notify the ntfy server of the homelab,
# which is reachable from the LAN and the tailnet.
{
  flake.modules.nixos.default =
    { lib, ... }:
    {
      custom.notify = {
        enable = lib.mkDefault true;
        server = "https://ntfy.lenz.casa";
        topic = "infra";
      };
    };
}
