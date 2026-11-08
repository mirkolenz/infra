{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.macpro = {
    system = "x86_64-linux";
    module =
      {
        pkgs,
        lib,
        ...
      }:
      {
        imports = [
          nixos.default
          "${inputs.nixos-hardware}/common/cpu/intel/cpu-only.nix"
          "${inputs.nixos-hardware}/common/gpu/amd"
        ];

        custom.features.unattended.enable = true;

        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
        boot.loader.systemd-boot.enable = true;

        # https://wiki.nixos.org/wiki/Hardware/Apple
        # https://superuser.com/a/1051137
        systemd.services.autorestart-powerloss = {
          script = "${lib.getExe' pkgs.pciutils "setpci"} -s 00:1f.0 0xa4.b=0";
          wantedBy = [ "multi-user.target" ];
          after = [ "multi-user.target" ];
        };

        networking.useDHCP = false;
        custom.lanMacvlan.parent = "enp9s0";
        systemd.network.networks."50-enp10s0" = {
          name = "enp10s0";
          DHCP = "yes";
          linkConfig.RequiredForOnline = false;
        };

        services.tailscale = {
          extraSetFlags = [
            "--advertise-exit-node"
          ];
          useRoutingFeatures = "server";
        };
      };
  };
}
