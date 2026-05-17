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
    ;
  cfg = config.virtualisation.quadlet.shellWrapper;

  wrapper = pkgs.writeShellApplication {
    name = "quadletctl";
    text = /* bash */ ''
      if [ "$#" -eq 0 ]; then
        set -- "help"
      fi
      command="$1"
      shift
      if [ "$command" = "exec" ]; then
        exec ${lib.getExe pkgs.podman} exec "systemd-$1" "''${@:2}"
      fi
      if [ "$command" = "update" ]; then
        exec ${lib.getExe pkgs.podman} auto-update "systemd-$1" "''${@:2}"
      fi
      if [ "$command" = "service" ]; then
        exec systemctl "''${2:-status}" "$1.service" "''${@:3}"
      fi
      if [ "$command" = "journal" ]; then
        exec journalctl --pager-end --no-hostname --unit "$1.service" "''${@:2}"
      fi
      if [ "$command" = "unshare" ]; then
        exec unshare --user --map-auto --setuid "$1" --setgid "$1" -- "''${@:2}"
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
  options.virtualisation.quadlet.shellWrapper = {
    enable = mkOption {
      default = true;
      type = with types; bool;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ wrapper ];
  };
}
