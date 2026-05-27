# https://wiki.nixos.org/wiki/NixOS_on_ARM#Installation
{
  inputs,
  pkgs,
  lib',
  ...
}:
{
  imports = lib'.flocken.getModules ./. ++ [
    "${inputs.nixos-hardware}/raspberry-pi/4"
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
}
