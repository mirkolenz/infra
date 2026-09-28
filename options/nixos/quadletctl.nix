{
  lib,
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
  podman = lib.getExe config.virtualisation.podman.package;
in
{
  options.virtualisation.quadlet.quadletctl = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the `quadletctl` helper.";
    };
  };

  config = mkIf cfg.enable {
    custom.commands.quadletctl.text = /* bash */ ''
      # @describe Manage quadlet containers and their services

      # @cmd Run a command in an existing container
      # @arg container!    Name of the quadlet container
      # @arg podman-args~  Further arguments of podman exec
      run() {
        exec ${podman} exec "systemd-$argc_container" "''${argc_podman_args[@]}"
      }

      # @cmd Run podman auto-update for a container
      # @arg container!    Name of the quadlet container
      # @arg podman-args~  Further arguments of podman auto-update
      update() {
        exec ${podman} auto-update "systemd-$argc_container" "''${argc_podman_args[@]}"
      }

      # @cmd Control the systemd service of a container
      # @arg container!       Name of the quadlet container
      # @arg action=status    Verb of systemctl
      # @arg systemctl-args~  Further arguments of systemctl
      service() {
        exec systemctl "$argc_action" "$argc_container.service" "''${argc_systemctl_args[@]}"
      }

      # @cmd Show the logs of the service of a container
      # @arg container!        Name of the quadlet container
      # @arg journalctl-args~  Further arguments of journalctl
      journal() {
        exec journalctl --pager-end --no-hostname --unit "$argc_container.service" "''${argc_journalctl_args[@]}"
      }

      # @cmd Run a command in a new user namespace
      # @arg id!       User and group ID inside the namespace
      # @arg command~  Command to run
      unshare() {
        exec unshare --user --map-auto --setuid "$argc_id" --setgid "$argc_id" -- "''${argc_command[@]}"
      }
    '';
  };
}
