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
  configurations.nixos.raspi = {
    system = "aarch64-linux";
    # nixos-hardware's raspberry-pi support enables an own nixpkgs overlay.
    sharedPkgs = false;
    module =
      { pkgs, ... }:
      {
        imports = [
          nixos.default
          "${inputs.nixos-hardware}/raspberry-pi/4"
        ];

        custom.features.unattended.enable = true;

        # PoE+ HAT fan control at the overlay defaults; `board-type=0x11` is the Pi 4B.
        hardware.raspberry-pi.configtxt.deviceTreeOverlays."board-type=0x11" = [
          { rpi-poe-plus = { }; }
        ];

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
  };
}
