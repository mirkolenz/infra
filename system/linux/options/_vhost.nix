{ lib, config, ... }:
let
  inherit (lib)
    types
    mkOption
    mkIf
    mkDefault
    mkBefore
    ;
in
{
  options = {
    dashboard = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to list this vhost as a card on the Homer dashboard.";
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
                "fas"
                "fab"
              ];
              default = "fas";
              description = "Font Awesome icon style prefix.";
            };
          };
        };
      };
    };
    reverseProxy = mkOption {
      default = { };
      type = types.submodule (
        { config, ... }:
        {
          options = {
            upstreams = mkOption {
              type = with types; listOf str;
              default = [ ];
              description = ''
                Caddy reverse_proxy upstreams. Defaults to
                ["127.0.0.1:<publishPort>"] when `publishPort` is set.
              '';
            };
            publishPort = mkOption {
              type = with types; nullOr port;
              default = null;
              description = ''
                Host-side loopback port. On quadlet containers, also seeds
                the PublishPort line so the container exposes containerPort
                on 127.0.0.1:publishPort.
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
          config.upstreams = mkIf (config.publishPort != null) (mkDefault [
            "127.0.0.1:${toString config.publishPort}"
          ]);
        }
      );
    };
  };
  config = {
    extraConfig = mkIf (config.reverseProxy.upstreams != [ ]) (mkBefore ''
      reverse_proxy ${toString config.reverseProxy.upstreams} {
        ${config.reverseProxy.extraConfig}
      }
      handle_errors {
        respond "{err.status_code} {err.status_text}: {err.message}" {err.status_code}
      }
    '');
  };
}
