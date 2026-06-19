# https://wiki.nixos.org/wiki/NixOS_on_ARM#Installation
{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.raspi.module =
    { pkgs, lib, ... }:
    {
      imports = [
        nixos.default
        "${inputs.nixos-hardware}/raspberry-pi/4"
      ];
      nixpkgs.hostPlatform = "aarch64-linux";

      # TODO: Work around https://github.com/NixOS/nixos-hardware/issues/1920: for kernel >=6.18
      # nixpkgs common-config enables PREEMPT_LAZY while nixos-hardware forces PREEMPT, leaving
      # two answers in the preemption-model choice and tripping the strict generate-config.pl
      # check. The rpi kernel hardcodes its patches and structured config, so the only injection
      # point is buildLinux: drop PREEMPT_LAZY there and keep nixos-hardware's PREEMPT.
      nixpkgs.overlays = [
        (_: prev: {
          buildLinux =
            args:
            prev.buildLinux (
              args
              // {
                structuredExtraConfig = args.structuredExtraConfig or { } // {
                  PREEMPT_LAZY = lib.mkForce lib.kernel.no;
                };
              }
            );
        })
      ];

      custom.features.withAlwaysOn = true;

      hardware.raspberry-pi."4" = {
        # https://github.com/NixOS/nixos-hardware/blob/master/raspberry-pi/4/poe-plus-hat.nix
        poe-plus-hat.enable = true;
      };

      services.tailscale = {
        extraSetFlags = [
          "--advertise-exit-node"
        ];
        useRoutingFeatures = "server";
      };

      environment.systemPackages = with pkgs; [
        raspberrypi-eeprom
      ];
    };
}
