{ lib, config, ... }:
{
  options.custom = {
    projectsPath = lib.mkOption {
      type = lib.types.path;
      default = "${config.home.homeDirectory}/${config.custom.projectsDir}";
      description = "Absolute path to custom.projectsDir on the machine.";
    };

    configPath = lib.mkOption {
      type = lib.types.path;
      default = "${config.custom.projectsPath}/mirkolenz/infra";
      description = "Path to the nix config on the machine.";
    };

    minReleaseAge = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = ''
        Days a package release must age before the package managers that support a cooldown install it,
        which are uv, npm, and bun, but neither cargo nor composer.
      '';
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
