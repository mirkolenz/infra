# `vendor`, which replaces the copies of live checkouts in the current project.
# Every `.git` entry is left out, so the project can commit the copy instead of embedding a repository.
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
          projectFile = {
            name = mkOption {
              type = types.str;
              description = "File of the project selecting the copy.";
            };
            source = mkOption {
              type = types.path;
              description = "Content of the project file, copied unless the project has one.";
            };
          };
        };
      }
    );
    default = { };
    description = "Checkouts of the `vendor` command, keyed by name.";
  };

  config = lib.mkIf (cfg != { }) {
    custom.commands.vendor.text = /* bash */ ''
      # @describe Replace the vendored copies of checkouts in the current project
      # @flag -f --force  Overwrite the project files selecting the copies
      # @arg checkouts+[${lib.concatStringsSep "|" (lib.attrNames cfg)}]

      # Copies a checkout into the project, given its source, target, project file and its content.
      vendor() {
        if [[ ! -d $1 ]]; then
          echo "Checkout $1 is missing" >&2
          exit 1
        fi

        ${lib.getExe pkgs.rsync} --archive --delete --mkpath --exclude=.git "$1/" "$2/"

        if [[ -e $3 && -z $argc_force ]]; then
          echo "Keeping $3, compare it with $4" >&2
        else
          cp --no-preserve=all "$4" "$3"
          echo "Wrote $3" >&2
        fi
      }

      for checkout in "''${argc_checkouts[@]}"; do
        case "$checkout" in
          ${lib.concatMapAttrsStringSep "\n" (
            name: checkout:
            "${name}) vendor ${
              lib.escapeShellArgs [
                checkout.source
                checkout.target
                checkout.projectFile.name
                checkout.projectFile.source
              ]
            } ;;"
          ) cfg}
        esac
      done
    '';
  };
}
