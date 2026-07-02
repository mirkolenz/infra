{ lib, config, ... }:
{
  options.custom = {
    configPath = lib.mkOption {
      type = lib.types.path;
      default = "${config.home.homeDirectory}/developer/mirkolenz/infra";
      description = "Path to the nix config on the machine.";
    };

    standalone = lib.mkOption {
      type = lib.types.bool;
      internal = true;
      readOnly = true;
      description = ''
        Whether this home-manager configuration is deployed standalone, i.e.
        without a NixOS/Darwin host managed alongside it (osConfig absent).
        Derived in the home base module; single source of truth for
        integrations that require matching host-level config, such as the
        1Password SSH agent.
      '';
    };
  };
}
