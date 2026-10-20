# Wrappers running the executables of packages within bubblewrap without network access,
# seeing only the nix store and a temporary home unless granted more.
# On Ubuntu, the nix bwrap needs an AppArmor profile granting `userns` to /nix/store/*/bin/bwrap
# while `kernel.apparmor_restrict_unprivileged_userns` is 1,
# and `dev.tty.legacy_tiocsti` should be 0, since the sandbox could otherwise inject input into the shared terminal.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.custom.bubblewrap = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          packages = mkOption {
            type = types.listOf types.package;
            description = "Packages whose executables are run within the sandbox, also forming its PATH.";
          };
          args = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "--share-net" ];
            description = "Arguments of bwrap, inserted verbatim into the wrapper to allow shell expansions.";
          };
          setup = mkOption {
            type = types.lines;
            default = "";
            description = "Shell code run outside the sandbox before entering it.";
          };
          init = mkOption {
            type = types.lines;
            default = "";
            description = "Shell code run within the sandbox before the executable.";
          };
        };
      }
    );
    default = { };
    description = "Sandboxes keyed by name, whose wrappers take precedence over unwrapped packages.";
  };

  config.home.packages = lib.mapAttrsToList (
    name: cfg:
    let
      init = pkgs.writeShellScript "${name}-bubblewrap-init" ''
        ${cfg.init}
        # restores the SIGINT ignored by the launcher, which bash itself cannot
        exec ${lib.getExe' pkgs.coreutils "env"} --default-signal=INT "$@"
      '';
      # runs the executable named like the link it was invoked through
      launcher = pkgs.writeShellApplication {
        name = "${name}-bubblewrap";
        runtimeInputs = with pkgs; [
          bubblewrap
          coreutils
        ];
        text = ''
          ${cfg.setup}
          args=(
            --unshare-all --unshare-user --disable-userns --die-with-parent --clearenv
            --ro-bind /nix/store /nix/store --proc /proc --dev /dev --tmpfs /tmp --tmpfs "$HOME"
            --ro-bind /etc/passwd /etc/passwd --ro-bind /etc/group /etc/group
            --ro-bind-try /etc/localtime /etc/localtime
            --setenv HOME "$HOME" --setenv PATH ${lib.makeBinPath cfg.packages} --setenv LANG C.UTF-8
            --setenv TERM "''${TERM:-dumb}" --setenv COLORTERM "''${COLORTERM-}"
            ${lib.concatLines cfg.args}
          )
          # bwrap dies on SIGINT, killing the sandbox through --die-with-parent,
          # so only the executable receives Ctrl-C
          trap ''' INT
          bwrap "''${args[@]}" -- ${init} "$(basename "$0")" "$@"
        '';
      };
    in
    lib.hiPrio (
      pkgs.runCommandLocal "${name}-bubblewrap" { } ''
        mkdir -p $out/bin

        for exe in ${lib.concatMapStringsSep " " (pkg: "${lib.getBin pkg}/bin/*") cfg.packages}; do
          ln -sf ${lib.getExe launcher} "$out/bin/$(basename "$exe")"
        done
      ''
    )
  ) config.custom.bubblewrap;
}
