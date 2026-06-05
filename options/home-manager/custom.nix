{ lib, config, ... }:
{
  options.custom = {
    configPath = lib.mkOption {
      type = lib.types.path;
      default = "${config.home.homeDirectory}/developer/mirkolenz/infra";
      description = "Path to the nix config on the machine.";
    };
  };
}
