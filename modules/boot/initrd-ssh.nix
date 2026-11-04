# Unlock LUKS devices over SSH from the initrd through a USB Ethernet adapter.
# Log in with `ssh -p 2222 root@<host>`.
# https://wiki.nixos.org/wiki/Remote_disk_unlocking
{
  flake.modules.nixos.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Not the system host key, the initrd sits unencrypted on the ESP.
      hostKey = "/etc/ssh/initrd_ssh_host_ed25519_key";
      hostKeyArg = lib.escapeShellArg hostKey;
    in
    {
      options.custom.initrdSsh.enable =
        lib.mkEnableOption "unlocking the LUKS devices over SSH from the initrd"
        // {
          default = config.boot.initrd.luks.devices != { };
          defaultText = lib.literalExpression "config.boot.initrd.luks.devices != { }";
        };

      config = lib.mkIf config.custom.initrdSsh.enable {
        boot.initrd = {
          # udev loads only the drivers matching present hardware.
          # Kconfig files of the candidates: https://github.com/torvalds/linux/tree/master/drivers/net
          availableKernelModules = [
            # USB adapters: Realtek, ASIX, Aquantia and class-compliant ones
            "r8152"
            "asix"
            "ax88179_178a"
            "aqc111"
            "cdc_ether"
            "cdc_ncm"
            # built-in ports: Intel, Realtek, Broadcom, Aquantia and Qualcomm Atheros
            "e1000e"
            "igb"
            "igc"
            "r8169"
            "tg3"
            "atlantic"
            "alx"
          ];
          network = {
            enable = true;
            # Hands NetworkManager unconfigured interfaces.
            flushBeforeStage2 = true;
            ssh = {
              enable = true;
              # Its own port keeps the second host key apart in known_hosts.
              port = 2222;
              authorizedKeys = config.custom.user.sshKeys;
              # A string, so it becomes an initrd secret instead of landing in the store.
              hostKeys = [ hostKey ];
            };
          };
          # The generic DHCP network of nixpkgs needs `networking.useDHCP`,
          # which NetworkManager turns off.
          systemd.network.networks."99-ethernet" = {
            matchConfig = {
              Type = "ether";
              Kind = "!*";
            };
            DHCP = "yes";
          };
          systemd.users.root.shell = "/bin/systemd-tty-ask-password-agent";
        };

        # The only hook before the bootloader install, which appends the key to the initrd.
        # Only the actions installing the bootloader need it.
        system.preSwitchChecks.initrdSshHostKey = ''
          if [[ $2 =~ ^(switch|boot)$ && ! -s ${hostKeyArg} ]]; then
            ${lib.getExe' pkgs.coreutils "mkdir"} -p ${lib.escapeShellArg (lib.dirOf hostKey)}
            # An empty key left by an interrupted run would make ssh-keygen prompt for overwriting.
            ${lib.getExe' pkgs.coreutils "rm"} -f ${hostKeyArg}
            ${lib.getExe' config.programs.ssh.package "ssh-keygen"} -q -t ed25519 -N "" -C "" -f ${hostKeyArg}
          fi
        '';
      };
    };
}
