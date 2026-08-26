# Standalone home-manager only: always-on default, auto-upgrade timer, the
# generic Linux sudo PATH shim and the bash to fish handover.
# Nix daemon config lives in modules/nix.
{
  flake.modules.homeManager.standalone =
    {
      lib,
      config,
      ...
    }:
    let
      # for generic linux, inject global paths into sudo PATH
      sudoPath = lib.concatStringsSep ":" [
        # add global paths
        "${config.home.profileDirectory}/bin"
        "/nix/var/nix/profiles/default/bin"
        "/nix/var/nix/profiles/default/sbin"
        # keep current paths
        "$(/usr/bin/sudo printenv PATH)"
      ];

      # nix.sh prepends the profile bin dir without checking whether it is already
      # present and targets.genericLinux sources it both from hm-session-vars and
      # from the bash init, on top of the system-wide /etc/profile.d copy.
      # Upstream bug, no option to opt out of the reordering yet:
      # https://github.com/nix-community/home-manager/issues/8076
      # https://github.com/nix-community/home-manager/issues/8790
      dedupePath = ''
        PATH="$(
          IFS=":"
          unique=""
          for entry in $PATH; do
            case ":$unique:" in
              *":$entry:"*) ;;
              *) unique="''${unique:+$unique:}$entry" ;;
            esac
          done
          printf "%s" "$unique"
        )"
      '';

      # Standalone home-manager cannot change the login shell in /etc/passwd, so
      # replace the interactive bash with fish, as suggested upstream until
      # https://github.com/nix-community/home-manager/issues/9006 lands.
      # Both shells export the marker, keeping a bash started from fish a bash.
      # Dumb terminals and `bash -ic` need a POSIX shell and are left alone.
      execFish = ''
        if [ -z "''${__HM_FISH_HANDOVER-}" ] && [ -z "''${BASH_EXECUTION_STRING-}" ] && [ "$TERM" != "dumb" ]; then
          export __HM_FISH_HANDOVER=1
          shopt -q login_shell && set -- --login
          exec ${lib.getExe config.programs.fish.package} "$@"
        fi
      '';
    in
    {
      custom.features.unattended.enable = lib.mkDefault true;

      custom.autoUpgrade = {
        enable = true;
        flake = "github:mirkolenz/infra";
      };

      home.shellAliases = {
        # Trailing space keeps the bash/zsh alias-expansion-after-sudo trick
        # (see modules/programs/shells.nix) working with the PATH shim.
        sudo = lib.mkIf config.targets.genericLinux.enable ''/usr/bin/sudo env "PATH=${sudoPath}" '';
      };

      programs.fish.shellInit = "set -gx __HM_FISH_HANDOVER 1";

      # mkAfter so this runs once the generic Linux nix.sh sourcing is done.
      programs.bash.initExtra = lib.mkAfter (dedupePath + execFish);
    };
}
