{
  flake.modules.nixos.orbstack =
    {
      lib,
      lib',
      config,
      ...
    }:
    {

      # /etc/nixos/configuration.nix
      security.sudo.wheelNeedsPassword = false;

      networking.useDHCP = false;

      systemd.network.networks."50-eth0" = {
        name = "eth0";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };

      users.users.${config.custom.user.login} = {
        uid = 501;
        extraGroups = [
          "wheel"
          "orbstack"
          "audio"
        ];

        # simulate isNormalUser, but UID < 1000
        isNormalUser = lib.mkForce false;
        isSystemUser = true;
        group = lib.mkForce "users";
        createHome = true;
        home = "/home/mlenz";
        homeMode = "700";
        useDefaultShell = true;
      };

      # OrbStack writes the machine name into /etc/hostname, which would clobber
      # the store file behind the default symlink. A mode makes it a copy.
      environment.etc.hostname.mode = "0644";

      # debugfs cannot be mounted in an unprivileged container,
      # and nixpkgs only excludes sys-kernel-config.mount for containers.
      systemd.suppressedSystemUnits = [ "sys-kernel-debug.mount" ];

      # Extra certificates from OrbStack.
      security.pki.certificateFiles = lib'.optionalPath /opt/orbstack-guest/run/extra-certs.crt;

      # /etc/nixos/orbstack.nix

      # Add OrbStack CLI tools to PATH
      environment.shellInit = /* bash */ ''
        . /opt/orbstack-guest/etc/profile-early

        # add your customizations here

        . /opt/orbstack-guest/etc/profile-late
      '';

      # Disable systemd-resolved
      services.resolved.enable = false;
      networking.resolvconf.enable = false;
      environment.etc."resolv.conf".source = "/opt/orbstack-guest/etc/resolv.conf";

      # Disable sshd
      services.openssh.enable = false;

      # systemd
      systemd.services = lib.genAttrs (map (name: "systemd-${name}") [
        "oomd"
        "userdbd"
        "udevd"
        "timesyncd"
        "timedated"
        "portabled"
        "nspawn@"
        "machined"
        "localed"
        "logind"
        "journald@"
        "journald"
        "journal-remote"
        "journal-upload"
        "importd"
        "hostnamed"
        "homed"
        "networkd"
      ]) (_: { serviceConfig.WatchdogSec = 0; });

      # ssh config
      programs.ssh.extraConfig = ''
        Include /opt/orbstack-guest/etc/ssh_config
      '';

      # indicate builder support for emulated architectures
      nix.settings.extra-platforms = [
        "i686-linux"
        "x86_64-linux"
      ];

      users.groups.orbstack.gid = 67278;
    };
}
