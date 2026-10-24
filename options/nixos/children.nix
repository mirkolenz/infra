{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.custom.children;

  hidden = pkgs.writeText "hidden.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=Hidden
    Hidden=true
  '';

  # The profile of a user precedes the system in XDG_DATA_DIRS, so these entries mask the system ones.
  # Without a terminal, the entries that need one would fail.
  hiddenEntries = pkgs.runCommandLocal "hidden-entries" { } ''
    mkdir -p $out/share/applications
    cd ${config.system.path}/share/applications
    for entry in $(grep -l '^Terminal=true' *.desktop) ${
      lib.concatMapStringsSep " " (id: "${id}.desktop") cfg.hidden
    }; do
      ln -s ${hidden} $out/share/applications/$entry
    done
  '';
in
{
  options.custom.children = {
    online = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "AppArmor globs of the executables the children may use the network with.";
    };
    sandboxed = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "AppArmor globs of the executables that may create user namespaces for their sandbox.";
    };
    denied = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "AppArmor globs of system executables the children may not run.";
    };
    hidden = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "IDs of system desktop entries hidden from the children, besides the ones that need a terminal.";
    };
  };

  # Keyed by the primary group, since defining users from the group members would recurse.
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          config.packages = lib.mkIf (config.group == "children") [ hiddenEntries ];
        }
      )
    );
  };
}
