{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.wsl = {
    system = "x86_64-linux";
    module =
      { config, ... }:
      {
        imports = [
          nixos.default
          inputs.nixos-wsl.nixosModules.default
        ];

        # resolv.conf is managed by config.wsl.wslConf.network.generateResolvConf
        services.resolved.enable = false;

        # https://nix-community.github.io/NixOS-WSL/options.html
        wsl = {
          enable = true;
          defaultUser = config.custom.user.login;
        };
      };
  };
}
