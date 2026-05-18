{
  lib,
  pkgs,
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

  isWildcard = c: c.virtualHost.wildcardDomain != null;
  dedicatedContainers = lib.filterAttrs (_: c: !isWildcard c) vhostContainers;
  wildcardContainers = lib.filterAttrs (_: c: isWildcard c) vhostContainers;

  mkWildcardEntry = c: {
    inherit (c.virtualHost) serverAliases extraConfig dashboard;
  };

  wildcardDomains = lib.mapAttrs (_: pairs: {
    virtualHosts = lib.listToAttrs (map (p: lib.nameValuePair p.name (mkWildcardEntry p.value)) pairs);
  }) (lib.groupBy (p: p.value.virtualHost.wildcardDomain) (lib.attrsToList wildcardContainers));

  shellWrapper = pkgs.writeShellApplication {
    name = "quadletctl";
    text = ''
      if [ "$#" -eq 0 ]; then
        set -- "help"
      fi
      command="$1"
      shift
      if [ "$command" = "exec" ]; then
        container="$1"
        shift
        exec ${lib.getExe config.virtualisation.podman.package} exec "systemd-$container" "$@"
      fi
      if [ "$command" = "update" ]; then
        container="$1"
        shift
        exec ${lib.getExe config.virtualisation.podman.package} auto-update "systemd-$container" "$@"
      fi
      if [ "$command" = "service" ]; then
        container="$1"
        shift
        action="''${1:-status}"
        shift
        exec systemctl "$action" "$container.service" "$@"
      fi
      if [ "$command" = "journal" ]; then
        container="$1"
        shift
        exec journalctl --pager-end --no-hostname --unit "$container.service" "$@"
      fi
      if [ "$command" = "unshare" ]; then
        id="$1"
        shift
        exec unshare --user --map-auto --setuid "$id" --setgid "$id" -- "$@"
      fi
      if [ "$command" = "help" ]; then
        echo "Usage: $0 <command> <args>

        Available commands:
        exec <container> <args>: Run a command in an existing container
        update <container> <args>: Run podman auto-update
        service <container> <action> <args>: Control the systemd service
        journal <container> <args>: Show the logs of the podman service
        unshare <id> <args>: Run a command in a new user namespace
        " >&2
        exit 0
      fi
    '';
  };
in
{
  options.virtualisation.quadlet = {
    containers = mkOption {
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
                  wildcardDomain = mkOption {
                    type = with types; nullOr str;
                    default = null;
                    description = ''
                      When non-null, route this container under
                      `services.caddy.wildcardDomains.<wildcardDomain>.virtualHosts.<container>`
                      and share the apex domain's wildcard certificate.
                      The subdomain label is the container's attribute name.

                      When null, the container gets a dedicated entry in
                      `services.caddy.virtualHosts.<container>` with its
                      own certificate (requires `hostName`).
                    '';
                  };
                  hostName = mkOption {
                    type = with types; nullOr str;
                    default = null;
                    description = ''
                      Primary FQDN for the dedicated site block. Mutually
                      exclusive with `wildcardDomain`.
                    '';
                  };
                  serverAliases = mkOption {
                    type = with types; listOf str;
                    default = [ ];
                    description = "Additional FQDNs added to this vhost's `host` matcher.";
                  };
                  extraConfig = mkOption {
                    type = types.lines;
                    default = "";
                    description = "Caddyfile snippet inside the site block (or `handle` block under a wildcard).";
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

    shellWrapper.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the `quadletctl` helper.";
    };
  };

  config = {
    assertions = lib.mapAttrsToList (name: c: {
      assertion = (c.virtualHost.wildcardDomain != null) != (c.virtualHost.hostName != null);
      message = "quadlet container '${name}' must set exactly one of virtualHost.{wildcardDomain,hostName}.";
    }) vhostContainers;

    services.caddy.virtualHosts = lib.mapAttrs' (
      name: c:
      lib.nameValuePair name {
        inherit (c.virtualHost)
          hostName
          serverAliases
          extraConfig
          dashboard
          ;
      }
    ) dedicatedContainers;

    services.caddy.wildcardDomains = wildcardDomains;

    environment.systemPackages = lib.optional config.virtualisation.quadlet.shellWrapper.enable shellWrapper;
  };
}
