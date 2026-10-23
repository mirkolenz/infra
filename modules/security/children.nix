# Confines the members of the `children` group with AppArmor, so they can only execute
# the programs of the system and of their own profile, not those of other users nor
# binaries they copied. AppArmor only gates execution here, all other access stays with
# the file permissions.
# Denials: journalctl -b --grep 'apparmor="DENIED"'
{
  flake.modules.nixos.children =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      children = lib.attrNames (
        lib.filterAttrs (_: user: lib.elem "children" user.extraGroups) config.users.users
      );

      allowlist = pkgs.apparmorRulesFromClosure {
        name = "children";
        baseRules = [ "priority=2 $path/** mrix" ];
      };

      # the graphics drivers are linked to /run/opengl-driver
      system = allowlist [
        config.system.path
        config.hardware.graphics.package
        config.environment.etc."systemd/user".source
        config.environment.etc."dbus-1".source
      ];

      # Higher priorities override the permissions of lower ones: everything is allowed,
      # except executing and mapping executable code outside of the allowlist.
      rules = name: ''
        all,
        priority=1 audit deny /** mx,
        # the setuid wrappers, e.g. unix_chkpwd for unlocking the screen
        priority=2 /run/wrappers/wrappers.*/* mrix,
        include "${system}"
        include "${allowlist config.users.users.${name}.packages}"
      '';

      # Path lookups fail for files outside the namespace and for deleted ones,
      # which systemd links after creating them with O_TMPFILE.
      flags = "flags=(attach_disconnected, mediate_deleted)";
    in
    {
      users.groups.children = { };

      security.apparmor = {
        enable = true;
        policies.children.profile = ''
          abi <abi/4.0>,
          include <tunables/global>

          # the user managers of the children, see systemd.services below
          ${lib.concatMapStrings (name: ''
            profile children-${name} ${flags} {
              ${rules name}
            }
          '') children}

          # pam_apparmor changes the session worker of greetd into the hat of the child before
          # it sources ~/.profile, while the greeter and the other sessions stay unrestricted.
          profile greetd ${lib.getExe config.services.greetd.package} flags=(attach_disconnected) {
            all,
            ${lib.concatMapStrings (name: ''
              ^${name} ${flags} {
                ${rules name}
              }
            '') children}
          }
        '';
      };

      # The greetd stack includes the login one, which therefore carries both rules.
      security.pam.services.login = {
        enableAppArmor = true;
        # Only greetd confines a session, so keep the children off the text consoles.
        rules.account.children = {
          order = config.security.pam.services.login.rules.account.unix.order - 10;
          control = "[success=die default=ignore]";
          modulePath = "${config.security.pam.package}/lib/security/pam_succeed_if.so";
          args = [
            "quiet"
            "service"
            "="
            "login"
            "user"
            "ingroup"
            "children"
          ];
        };
      };

      systemd.services = {
        # Without the policies, the children would log in unconfined.
        greetd = {
          requires = [ "apparmor.service" ];
          after = [ "apparmor.service" ];
        };
      }
      // lib.listToAttrs (
        map (
          name:
          lib.nameValuePair "user@${toString config.users.users.${name}.uid}" {
            overrideStrategy = "asDropin";
            serviceConfig.AppArmorProfile = "children-${name}";
          }
        ) children
      );

      # A switch reloads the allowlist with the store paths of the new generation,
      # which would deny the programs the running sessions still start from the old one.
      system.autoUpgrade.operation = "boot";
    };
}
