# Podman containers on Linux + darwin.
{
  flake.modules.nixos.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      environment.systemPackages = lib.mkIf config.virtualisation.podman.enable (
        with pkgs;
        [
          podman-compose
        ]
      );
      virtualisation.podman = {
        enable = true;
        # logDriver = "json-file";
        autoPrune = {
          enable = true;
          dates = "daily";
        };
      };
      users = lib.mkIf config.virtualisation.podman.enable {
        users.containers = {
          isSystemUser = true;
          group = "containers";
          subUidRanges = [
            {
              startUid = 2147483647;
              count = 2147483648;
            }
          ];
          subGidRanges = [
            {
              startGid = 2147483647;
              count = 2147483648;
            }
          ];
        };
        groups.containers = { };
      };
      networking.firewall.interfaces."podman*" = lib.mkIf config.virtualisation.podman.enable {
        # dns
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };
      custom.commands.userns.text = /* bash */ ''
        # @describe Run a command in a new user namespace
        # @arg id!       User and group ID inside the namespace
        # @arg command~  Command to run

        exec unshare --user --map-auto --setuid "$argc_id" --setgid "$argc_id" -- "''${argc_command[@]}"
      '';
    };

  flake.modules.darwin.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      virtualisation.podman.enable = true;

      environment.systemPackages = lib.mkIf config.virtualisation.podman.enable (
        with pkgs;
        [
          podman-compose
        ]
      );
    };
}
