# Linux builds on darwin, either via the NixOS machine of OrbStack (determinate distributed builds),
# including the SSH host entry the builder connects through, or via the native builder of determinate-nixd.
{ config, lib, ... }:
let
  cfg = config.custom.linuxBuilder;
  orbstack = "/Users/${config.custom.user.login}/.orbstack/ssh";
in
{
  options.custom.linuxBuilder = lib.mkOption {
    type = lib.types.enum [
      "native"
      "orbstack"
    ];
    default = "native";
    description = ''
      The builder for Linux derivations.
      `native` runs a VM on the macOS Virtualization framework, which requires
      the native-linux-builder feature to be granted for the FlakeHub account.
      https://determinate.systems/blog/changelog-determinate-nix-384/
      `orbstack` runs them on the NixOS machine of OrbStack.
    '';
  };

  config = lib.mkMerge [
    {
      # https://github.com/DeterminateSystems/determinate/blob/main/modules/nix-darwin/default.nix
      # Set in both cases, an unset state falls back to the default of determinate-nixd.
      determinateNix.determinateNixd.builder.state = if cfg == "native" then "enabled" else "disabled";

      # determinate-nixd only writes the native builder to `nix.conf` on start,
      # and Nix falls back to a stale entry when the remote builder declines a job.
      system.activationScripts.postActivation.text = /* bash */ ''
        if grep -q '^external-builders' /etc/nix/nix.conf; then builder=native; else builder=orbstack; fi

        if [ "$builder" != ${cfg} ]; then
          echo "Determinate Nixd: Restarting to apply the ${cfg} Linux builder"
          launchctl kickstart -k system/systems.determinate.nix-daemon
        fi
      '';
    }

    (lib.mkIf (cfg == "orbstack") {
      # https://docs.orbstack.dev/machines/ssh
      # The user selects the OrbStack machine, which logs in as the default (trusted) user.
      # OrbStack keeps its host key in the known_hosts file it maintains.
      # The ServerAliveInterval and IPQoS settings make remote builds more reliable,
      # especially if there are long silent periods with no logs emitted by a build.
      # https://github.com/LnL7/nix-darwin/blob/master/modules/nix/linux-builder.nix
      programs.ssh.extraConfig = ''
        Host orbstack-builder
          Hostname 127.0.0.1
          Port 32222
          User nixos
          IdentityFile ${orbstack}/id_ed25519
          IdentitiesOnly yes
          UserKnownHostsFile ${orbstack}/known_hosts
          ServerAliveInterval 60
          IPQoS throughput
      '';
      determinateNix = {
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
            maxJobs = 16;
            supportedFeatures = [
              "benchmark"
              "big-parallel"
              "kvm"
              "nixos-test"
            ];
          }
        ];
      };
    })
  ];
}
