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

      networking = {
        dhcpcd.enable = false;
        useDHCP = false;
        useHostResolvConf = false;
      };

      systemd.network = {
        enable = true;
        networks."50-eth0" = {
          name = "eth0";
          networkConfig = {
            DHCP = "ipv4";
            IPv6AcceptRA = true;
          };
          linkConfig.RequiredForOnline = "routable";
        };
      };

      users.users.${config.custom.user.login} = {
        uid = 501;
        extraGroups = [
          "wheel"
          "orbstack"
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

      # Faster DHCP - OrbStack uses SLAAC exclusively
      networking.dhcpcd.extraConfig = ''
        noarp
        noipv6
      '';

      # Disable sshd
      services.openssh.enable = false;

      # systemd
      systemd.services."systemd-oomd".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-userdbd".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-udevd".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-timesyncd".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-timedated".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-portabled".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-nspawn@".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-machined".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-localed".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-logind".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-journald@".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-journald".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-journal-remote".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-journal-upload".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-importd".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-hostnamed".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-homed".serviceConfig.WatchdogSec = 0;
      systemd.services."systemd-networkd".serviceConfig.WatchdogSec =
        lib.mkIf config.systemd.network.enable 0;

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
