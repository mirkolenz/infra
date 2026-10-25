# Confines the `children` group with AppArmor: they may only run the programs of the system,
# and only those of custom.children.online may reach the network.
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
      # The store hash alone identifies a path, which keeps the compiled policy small.
      allowed =
        pkgs.apparmorRulesFromClosure
          {
            name = "children";
            baseRules = [ "priority=2 \${path%%-*}-*/** mrix" ];
          }
          [
            config.system.path
            config.systemd.tmpfiles.settings.graphics-driver."/run/opengl-driver"."L+".argument
            config.environment.etc."systemd/user".source
            config.environment.etc."dbus-1".source
            # loaded by the worker that unlocks the screen, the file in /etc would add all of pam.d
            (pkgs.writeText "login" config.security.pam.services.login.text)
          ];

      # Files outside the namespace, e.g. the journal socket, get this prefix,
      # which unlike the root cannot alias an allowed path.
      disconnected = "attach_disconnected.path=/disconnected/";

      # Deleted files include the ones systemd creates with O_TMPFILE.
      flags = "flags=(${disconnected}, mediate_deleted)";

      # The allowlist of the children profile is stacked with one of the policies,
      # so it is compiled only once and both must allow an access.
      confinement = "children//&children-offline";

      # Unix sockets stay, e.g. for D-Bus, CUPS and resolved.
      noInet = ''
        audit deny network inet,
        audit deny network inet6,
      '';

      transitions =
        policy: lib.concatMapStrings (binaries: "priority=1 ${binaries} mrPx -> children-${policy},\n");

      # A user namespace could bind mount any binary over an allowed or online one,
      # so only the online and sandboxed programs keep it, the latter offline and without transitions.
      policies = {
        offline = ''
          ${noInet}
          audit deny userns,
          ${transitions "online" config.custom.children.online}
          ${transitions "sandbox" config.custom.children.sandboxed}
        '';
        online = "";
        sandbox = noInet;
      };
    in
    {
      assertions = [
        {
          assertion = config.services.displayManager.gdm.enable;
          message = "pam_apparmor only confines the children in sessions of GDM.";
        }
      ];

      security.apparmor = {
        enable = true;
        policies.children.profile = ''
          abi <abi/4.0>,
          include <tunables/global>

          # Higher priorities override lower ones: everything is allowed,
          # except running and mapping code outside of the allowlist.
          profile children ${flags} {
            all,
            priority=1 audit deny /** mx,
            # setuid wrappers, e.g. for polkit dialogs
            priority=2 /run/wrappers/wrappers.*/* mrix,
            include "${allowed}"
            ${lib.concatMapStrings (
              binaries: "priority=3 audit deny ${binaries} mx,\n"
            ) config.custom.children.denied}
          }

          ${lib.concatMapAttrsStringSep "\n" (name: rules: ''
            profile children-${name} ${flags} {
              all,
              ${rules}
            }
          '') policies}

          # pam_apparmor switches the GDM worker to the hat of the primary group, which moves
          # everything it runs, including the login shell, into the stack. px keeps the environment,
          # which secure execution would hide from the session.
          profile gdm-session-worker ${pkgs.gdm}/libexec/gdm-session-worker flags=(${disconnected}) {
            all,
            ^children flags=(${disconnected}) {
              all,
              priority=1 /** px -> ${confinement},
            }
          }
        '';
      };

      # DFA minimization takes most of the compile time but barely shrinks the policy.
      environment.etc."apparmor/parser.conf".text = lib.mkAfter ''
        Optimize=no-minimize
      '';

      # The GDM stacks include this one.
      security.pam.services.login = {
        enableAppArmor = true;
        # Only GDM confines a session, so keep the children off the text consoles.
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
        # fail closed
        display-manager.requires = [ "apparmor.service" ];
      }
      // lib.mapAttrs' (
        _: user:
        lib.nameValuePair "user@${toString user.uid}" {
          overrideStrategy = "asDropin";
          serviceConfig.AppArmorProfile = confinement;
        }
      ) config.custom.children.users;

      # A switch would deny running sessions the programs of the old generation.
      system.autoUpgrade.operation = "boot";
    };
}
