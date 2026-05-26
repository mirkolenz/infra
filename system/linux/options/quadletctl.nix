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
    mkIf
    ;

  cfg = config.virtualisation.quadlet.quadletctl;
in
{
  options.virtualisation.quadlet.quadletctl = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the `quadletctl` helper.";
    };

    package = mkOption {
      type = types.package;
      description = "The `quadletctl` package to install.";
      default = pkgs.writeShellApplication {
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
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
