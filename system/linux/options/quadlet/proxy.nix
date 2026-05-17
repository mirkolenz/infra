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
  cfg = config.virtualisation.quadlet.proxy;

  enabledVhosts = lib.filter (v: v.enable && v.extraConfig != "") (
    lib.mapAttrsToList (_: c: c.virtualHost) (
      lib.filterAttrs (_: c: c.enable) config.virtualisation.quadlet.containers
    )
    ++ lib.attrValues cfg.virtualHosts
  );

  displayName =
    vhost:
    if cfg.primaryDomain != null then
      lib.removeSuffix ".${cfg.primaryDomain}" vhost.hostName
    else
      vhost.hostName;

  toCaddyVhost = v: { inherit (v) serverAliases extraConfig; };

  toHomerItem = v: {
    name = displayName v;
    url = "https://${v.hostName}";
    target = "_blank";
    icon = "fa-${v.icon.style} fa-${v.icon.name}";
  };
in
{
  options.virtualisation.quadlet.proxy = {
    enable = mkEnableOption "Reverse proxy with Caddy and a Homer dashboard";

    dashboard = {
      enable = mkEnableOption "Homer dashboard listing every enabled vhost";
      name = mkOption {
        type = types.str;
        default = "dash";
        description = "Subdomain for the dashboard.";
      };
      title = mkOption {
        type = types.str;
        default = "Services";
        description = "Dashboard page title and group name.";
      };
    };

    primaryDomain = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        FQDN suffix used as a default for container vhost `hostName`s and
        the dashboard site address. Stripped from `hostName` for display in
        the dashboard.
      '';
    };

    virtualHosts = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            imports = [ ./_vhost.nix ];
            hostName = lib.mkDefault (
              if cfg.primaryDomain != null then "${name}.${cfg.primaryDomain}" else name
            );
          }
        )
      );
      description = ''
        Caddy virtual hosts keyed by subdomain (or FQDN via explicit
        `hostName`). When `primaryDomain` is set, the key is treated as a
        subdomain and joined with it; otherwise the key is used as-is.
        Each enabled entry also produces a card on the Homer dashboard.
      '';
    };
  };

  config = lib.mkIf (config.virtualisation.quadlet.enable && cfg.enable) {
    assertions = [
      {
        assertion = !cfg.dashboard.enable || cfg.primaryDomain != null;
        message = "virtualisation.quadlet.proxy.primaryDomain must be set when the dashboard is enabled";
      }
    ];

    services.caddy = {
      enable = true;
      openFirewall = true;
      virtualHosts = lib.listToAttrs (
        map (v: {
          name = v.hostName;
          value = toCaddyVhost v;
        }) enabledVhosts
      );
    };

    services.homer = lib.mkIf cfg.dashboard.enable {
      enable = true;
      virtualHost = {
        caddy.enable = true;
        domain = "${cfg.dashboard.name}.${cfg.primaryDomain}";
      };
      settings = {
        inherit (cfg.dashboard) title;
        header = false;
        footer = false;
        connectivityCheck = false;
        defaults = {
          layout = "columns";
          colorTheme = "auto";
        };
        services = [
          {
            name = cfg.dashboard.title;
            items = map toHomerItem (lib.sort (a: b: a.hostName < b.hostName) enabledVhosts);
          }
        ];
      };
    };
  };
}
