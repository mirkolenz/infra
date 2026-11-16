{ lib, config, ... }:
let
  inherit (lib) mkOption types;

  # the registries with a cooldown, mapped to the tools that honor it
  registries = {
    pypi = "uv";
    npm = "npm and bun";
    packagist = "Composer";
    github = "`bumpctl`, before it offers a release as the new tag of a GitHub Action or flake input";
  };
in
{
  config.home.sessionVariables.BUMP_MIN_AGE = config.custom.minReleaseAge.github;

  options.custom = {
    configPath = mkOption {
      type = types.path;
      default = "${config.xdg.userDirs.projects}/mirkolenz/infra";
      description = "Path to the nix config on the machine.";
    };

    minReleaseAge = mkOption {
      type = types.submodule (
        { config, ... }:
        {
          options = {
            default = mkOption {
              type = types.ints.positive;
              default = 1;
              description = "Days a release must age before it is installed, unless its registry overrides it.";
            };
          }
          // lib.mapAttrs (
            name: tools:
            mkOption {
              type = types.ints.positive;
              default = config.default;
              defaultText = lib.literalExpression "config.custom.minReleaseAge.default";
              description = "Days a release of ${name} must age for ${tools}.";
            }
          ) registries;
        }
      );
      default = { };
      description = "Cooldowns of the package registries, in days.";
    };

    standalone = mkOption {
      type = types.bool;
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
