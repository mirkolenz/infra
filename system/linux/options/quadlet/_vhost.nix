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
    ;
  rp = config.reverseProxy;
in
{
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
    icon = mkOption {
      default = { };
      description = "Font Awesome icon used in the Homer dashboard card.";
      type = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            default = "globe";
            description = "Font Awesome icon name.";
          };
          style = mkOption {
            type = types.enum [
              "solid"
              "brands"
            ];
            default = "solid";
            description = "Font Awesome icon style.";
          };
        };
      };
    };
    reverseProxy = mkOption {
      default = { };
      type = types.submodule {
        options = {
          upstreams = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = ''
              Caddy reverse_proxy upstreams (e.g. ["127.0.0.1:8080"],
              ["unix//run/foo.sock"], ["https://backend.internal:8443"]).
              Multiple entries enable Caddy's built-in load balancing.
              Defaults to ["127.0.0.1:<publishPort>"] when `publishPort`
              is set, so quadlet containers don't have to repeat it; set
              explicitly to point at one or more non-container services.
            '';
          };
          publishPort = mkOption {
            type = with types; nullOr port;
            default = null;
            description = ''
              Host-side loopback port. When set on a quadlet container's
              virtualHost, the container publishes containerPort on
              127.0.0.1:publishPort; also seeds the default for `upstreams`.
            '';
          };
          containerPort = mkOption {
            type = types.port;
            default = 80;
            description = "Port the upstream service listens on inside its container.";
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Caddyfile snippet inside the generated `reverse_proxy` block,
              e.g. for `transport http { ... }`, `header_up`, or load
              balancing options. When non-empty the directive is emitted
              in block form: `reverse_proxy <upstreams> { ... }`.
            '';
          };
        };
      };
    };
  };
  config = {
    reverseProxy.upstreams = lib.mkIf (rp.publishPort != null) (
      lib.mkDefault [
        "127.0.0.1:${toString rp.publishPort}"
      ]
    );
    extraConfig = lib.mkIf (rp.upstreams != [ ]) (
      lib.mkBefore (
        if rp.extraConfig == "" then
          "reverse_proxy ${toString rp.upstreams}"
        else
          ''
            reverse_proxy ${toString rp.upstreams} {
              ${rp.extraConfig}
            }
          ''
      )
    );
  };
}
