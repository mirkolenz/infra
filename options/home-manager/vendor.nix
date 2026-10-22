# `vendor`, which replaces the copies of live checkouts in the current project, see pkgs/by-name/vendor.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.custom.vendor;
in
{
  options.custom.vendor = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          source = mkOption {
            type = types.str;
            description = "Location of the live checkout.";
          };
          target = mkOption {
            type = types.str;
            description = "Location of the copy in the project.";
          };
          projectFile = mkOption {
            type = types.nullOr (
              types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                    description = "File of the project selecting the copy.";
                  };
                  source = mkOption {
                    type = types.path;
                    description = "Content of the project file, copied unless the project has one.";
                  };
                };
              }
            );
            default = null;
            description = "Project file selecting the copy, if the project cannot reference it directly.";
          };
        };
      }
    );
    default = { };
    description = "Checkouts of the `vendor` command, keyed by name.";
  };

  config = lib.mkIf (cfg != { }) {
    home.packages = [
      (pkgs.vendor.withConfig cfg)
    ];
  };
}
