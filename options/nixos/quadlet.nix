{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    mkEnableOption
    mkIf
    ;

  vhostContainers = lib.filterAttrs (
    _: c: c.enable && c.virtualHost.enable && c.virtualHost.reverseProxy.publishPort != null
  ) config.virtualisation.quadlet.containers;
in
{
  options.virtualisation.quadlet.containers = mkOption {
    type = types.attrsOf (
      types.submodule (
        { config, ... }:
        let
          rp = config.virtualHost.reverseProxy;
        in
        {
          options.virtualHost = mkOption {
            default = { };
            type = types.submodule {
              imports = [ ./_vhost.nix ];
              options = {
                enable = mkEnableOption "this virtual host" // {
                  default = true;
                };
                hostName = mkOption {
                  type = types.str;
                  description = "Primary FQDN for this virtual host.";
                };
                serverAliases = mkOption {
                  type = with types; listOf str;
                  default = [ ];
                  description = "Additional FQDNs that route to this vhost.";
                };
                extraConfig = mkOption {
                  type = types.lines;
                  default = "";
                  description = "Caddyfile snippet inside the site block.";
                };
              };
            };
          };
          config.containerConfig.PublishPort = mkIf (rp.publishPort != null) [
            "127.0.0.1:${toString rp.publishPort}:${toString rp.containerPort}"
          ];
        }
      )
    );
  };

  config.services.caddy.virtualHosts = lib.mapAttrs (_: c: {
    inherit (c.virtualHost)
      hostName
      serverAliases
      extraConfig
      dashboard
      ;
  }) vhostContainers;
}
