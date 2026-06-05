# Remote Linux builds via the OrbStack builder VM (determinate distributed builds),
# including the SSH host entry the builder connects through.
{
  flake.modules.darwin.default =
    { config, ... }:
    {
      # https://github.com/LnL7/nix-darwin/blob/master/modules/nix/linux-builder.nix
      # The ServerAliveInterval and IPQoS settings have been found to make remote builds more reliable,
      # especially if there are long silent periods with no logs emitted by a build.
      # https://docs.orbstack.dev/machines/ssh
      programs.ssh.extraConfig = ''
        Host orbstack-builder
          Hostname 127.0.0.1
          Port 32222
          ServerAliveInterval 60
          IPQoS throughput
      '';
      # https://github.com/DeterminateSystems/determinate/blob/4df6b4539dfaca0792d8c6123962f3786d1eaabc/modules/nix-darwin/default.nix#L680
      determinateNix = {
        determinateNixd.builder.state = "disabled";
        customSettings.builders-use-substitutes = true;
        distributedBuilds = true;
        buildMachines = [
          {
            hostName = "orbstack-builder";
            protocol = "ssh-ng";
            systems = [
              "i686-linux"
              "x86_64-linux"
              "aarch64-linux"
            ];
            sshUser = "nixos";
            sshKey = "/Users/${config.custom.user.login}/.orbstack/ssh/id_ed25519";
            maxJobs = 16;
            supportedFeatures = [
              "benchmark"
              "big-parallel"
              "kvm"
              "nixos-test"
            ];
            # execute the following once:
            # sudo ssh -i ~/.orbstack/ssh/id_ed25519 nixos@orbstack-builder
            # alternatively, hard-code the key per host
            # publicHostKey = "";
          }
        ];
      };
    };
}
