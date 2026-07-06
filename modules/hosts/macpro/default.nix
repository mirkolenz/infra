{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.macpro.module =
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        nixos.default
        "${inputs.nixos-hardware}/apple"
        "${inputs.nixos-hardware}/common/cpu/intel/cpu-only.nix"
        "${inputs.nixos-hardware}/common/gpu/amd"
        "${inputs.nixos-hardware}/common/pc/ssd"
      ];

      custom.features.unattended.enable = true;

      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
        efi.efiSysMountPoint = "/boot";
      };

      virtualisation.libvirtd.enable = true;

      # https://wiki.nixos.org/wiki/Hardware/Apple
      # https://superuser.com/a/1051137
      systemd.services.autorestart-powerloss = {
        script = "${lib.getExe' pkgs.pciutils "setpci"} -s 00:1f.0 0xa4.b=0";
        wantedBy = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
      };

      networking.useDHCP = false;
      systemd.network = {
        # physical
        networks."50-enp9s0" = {
          name = "enp9s0";
          macvlan = [ "mv0" ];
          linkConfig.RequiredForOnline = false;
          networkConfig = {
            LinkLocalAddressing = false;
            IPv6AcceptRA = false;
          };
        };
        networks."50-enp10s0" = {
          name = "enp10s0";
          DHCP = "yes";
          linkConfig.RequiredForOnline = false;
        };
        # virtual
        netdevs."50-mv0" = {
          netdevConfig = {
            Name = "mv0";
            Kind = "macvlan";
          };
          macvlanConfig.Mode = "bridge";
        };
        networks."50-mv0" = {
          name = "mv0";
          DHCP = "yes";
          linkConfig.RequiredForOnline = true;
        };
      };

      services.tailscale = {
        extraSetFlags = [
          "--advertise-exit-node"
        ];
        useRoutingFeatures = "server";
      };

      powerManagement.cpuFreqGovernor = "powersave";
    };
}
