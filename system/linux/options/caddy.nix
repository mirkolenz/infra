{ lib, config, ... }:
let
  inherit (lib)
    types
    mkOption
    ;

  mkSubdomain = domain: name: vh: ''
    @${name} host ${toString ([ "${name}.${domain}" ] ++ vh.serverAliases)}
    handle @${name} {
      ${vh.extraConfig}
    }
  '';

  mkWildcard =
    wildcard:
    lib.concatLines (
      lib.optional (wildcard.extraConfig != "") wildcard.extraConfig
      ++ lib.mapAttrsToList (mkSubdomain wildcard.domain) wildcard.virtualHosts
    );
in
{
  options.services.caddy = {
    virtualHosts = mkOption {
      type = types.attrsOf (types.submodule ./_vhost.nix);
    };

    wildcardDomains = mkOption {
      default = { };
      description = ''
        Caddy site blocks that obtain a single ACME wildcard certificate
        for `*.<domain>` and dispatch declared subdomains via `host` matchers.

        Sharing one certificate across many subdomains sidesteps Let's
        Encrypt's rate limit of 50 certificates per registered domain per
        week. Requires an ACME DNS-01 challenge provider in
        `services.caddy.globalConfig` (e.g. `acme_dns cloudflare ...`).
      '';
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              domain = mkOption {
                type = types.str;
                default = name;
                description = "Apex domain. Defaults to the attribute name. The site address is `*.<domain>`.";
              };
              extraConfig = mkOption {
                type = types.lines;
                default = "";
                description = "Caddyfile snippet emitted before any per-subdomain matchers (shared `tls`, `log`, etc.).";
              };
              virtualHosts = mkOption {
                default = { };
                description = "Subdomains routed by this wildcard. Attribute name is the subdomain label.";
                type = types.attrsOf (
                  types.submodule {
                    imports = [ ./_vhost.nix ];
                    options = {
                      serverAliases = mkOption {
                        type = with types; listOf str;
                        default = [ ];
                        description = "Additional FQDNs in this subdomain's `host` matcher.";
                      };
                      extraConfig = mkOption {
                        type = types.lines;
                        default = "";
                        description = "Caddyfile snippet inside the `handle` block.";
                      };
                    };
                  }
                );
              };
            };
          }
        )
      );
    };
  };

  config.services.caddy.virtualHosts = lib.mapAttrs' (
    _: wildcard:
    lib.nameValuePair "*.${wildcard.domain}" {
      hostName = "*.${wildcard.domain}";
      extraConfig = mkWildcard wildcard;
      dashboard.enable = false;
    }
  ) config.services.caddy.wildcardDomains;
}
