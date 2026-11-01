# Joins the LAN through a macvlan child instead of the physical interface itself.
# Macvlan containers on the same parent are unreachable from the parent interface,
# but reachable from a sibling macvlan, so hosts running such containers need this.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.custom.lanMacvlan;
in
{
  options.custom.lanMacvlan = {
    parent = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Physical LAN interface without an address of its own, or null to disable.";
    };
    name = mkOption {
      type = types.str;
      default = "mv0";
      description = "Name of the macvlan child that holds the LAN address via DHCP.";
    };
    addresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional static addresses with prefix length on the macvlan child.";
    };
  };

  config.systemd.network = lib.mkIf (cfg.parent != null) {
    networks."50-${cfg.parent}" = {
      name = cfg.parent;
      macvlan = [ cfg.name ];
      linkConfig.RequiredForOnline = false;
      networkConfig = {
        LinkLocalAddressing = false;
        IPv6AcceptRA = false;
      };
    };
    netdevs."50-${cfg.name}" = {
      netdevConfig = {
        Name = cfg.name;
        Kind = "macvlan";
      };
      macvlanConfig.Mode = "bridge";
    };
    networks."50-${cfg.name}" = {
      name = cfg.name;
      DHCP = "yes";
      address = cfg.addresses;
      linkConfig.RequiredForOnline = true;
    };
  };
}
