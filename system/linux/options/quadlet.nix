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

    shellWrapper.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the `quadletctl` helper.";
    };
  };

  config = {
    services.caddy.virtualHosts = lib.mapAttrs (_: c: {
      inherit (c.virtualHost)
        hostName
        serverAliases
        extraConfig
        dashboard
        ;
    }) vhostContainers;

    environment.systemPackages = lib.optional config.virtualisation.quadlet.shellWrapper.enable shellWrapper;
  };
}
