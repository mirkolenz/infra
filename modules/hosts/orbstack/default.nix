{ config, ... }:
let
  inherit (config.flake.modules) nixos;
  module = system: {
    imports = [
      nixos.default
      nixos.orbstack
    ];
    nixpkgs.hostPlatform = system;
  };
in
{
  # NixOS-in-OrbStack container base (the guest integration lives in hardware.nix).
  flake.modules.nixos.orbstack =
    {
      modulesPath,
      config,
      lib,
      ...
    }:
    {
      # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/lxc-instance-common.nix
      imports = [
        "${modulesPath}/virtualisation/lxc-container.nix"
      ];

      # lxc imports installer/cd-dvd/channel.nix
      system.installer.channel.enable = false;

      nix.settings.trusted-users = [ config.custom.user.login ];

      home-manager.users.${config.custom.user.login} = {
        programs.fish.functions.fish_greeting.body = lib.mkForce "";
      };

      custom.features.extras.enable = lib.mkDefault true;
    };

  configurations.nixos = {
    orbstack.module = module "aarch64-linux";
    orbstack-intel.module = module "x86_64-linux";
  };
}
