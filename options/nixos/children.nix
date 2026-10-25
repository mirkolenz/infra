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

  # Without a terminal, the entries that need one would fail.
  hiddenEntries = pkgs.runCommandLocal "hidden-entries" { } ''
    mkdir $out
    cd ${config.system.path}/share/applications
    for entry in $(grep -l '^Terminal=true' *.desktop) ${
      lib.concatMapStringsSep " " (id: "${id}.desktop") cfg.hidden
    }; do
      ln -s ${hidden} $out/$entry
    done
  '';
in
{
  options.custom.children = {
    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.str;
            };
            uid = lib.mkOption {
              type = lib.types.int;
            };
          };
        }
      );
      default = { };
      description = "Accounts of the children, all with the primary group `children`.";
    };
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

  config = lib.mkIf (cfg.users != { }) {
    # pam_apparmor picks the hat of the children by their primary group.
    users.users = lib.mapAttrs (_: user: {
      inherit (user) description uid;
      isNormalUser = true;
      group = "children";
    }) cfg.users;

    users.groups.children = { };

    # A stable path keeps the rules of the users from changing with every generation.
    environment.etc."children/applications".source = hiddenEntries;

    # XDG_DATA_HOME precedes XDG_DATA_DIRS, which wrappers like the one of GNOME Shell prefix with their own entries.
    systemd.user.tmpfiles.users = lib.mapAttrs (_: _: {
      rules = [ "L+ %h/.local/share/applications - - - - /etc/children/applications" ];
    }) cfg.users;
  };
}
