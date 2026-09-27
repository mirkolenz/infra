# Nix wiring across home-manager, nixos and darwin: GC, store optimisation,
# determinate hookup, the secrets include and the nix tooling.
# The settings attrsets themselves live in settings.nix.
{
  flake.modules.nixos.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      nix = {
        package = lib.mkForce pkgs.determinate-nix;
        channel.enable = false;
        extraOptions = ''
          !include nix.secrets.conf
        '';
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };
        optimise = {
          automatic = true;
        };
      };
      # we do this ourselves
      nixpkgs.flake = {
        setFlakeRegistry = false;
        setNixPath = false;
      };
      custom.commands = {
        # https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/tasks/auto-upgrade.nix#L268
        needs-reboot = /* bash */ ''
          booted="$(readlink /run/booted-system/{initrd,kernel,kernel-modules})"
          built="$(readlink /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"

          if [ "$booted" != "$built" ]; then
            echo "Reboot needed"
            exit 1
          else
            echo "No reboot needed"
            exit 0
          fi
        '';
        nixos-profile = /* bash */ ''
          if [ "$#" -lt 1 ]; then
            echo "Usage: $0 COMMAND [NIX_PROFILE_ARGS...]" >&2
            exit 1
          fi
          command="$1"
          shift
          exec ${lib.getExe config.nix.package} profile "$command" --profile /nix/var/nix/profiles/system "$@"
        '';
      };
    };

  flake.modules.darwin.base =
    { lib, ... }:
    {
      # https://github.com/DeterminateSystems/determinate/blob/main/modules/nix-darwin/default.nix
      determinateNix = {
        # https://docs.determinate.systems/determinate-nix#determinate-nixd-configuration
        determinateNixd = {
          garbageCollector.strategy = "automatic";
          # Linux builds via a VM on the macOS Virtualization framework, requires
          # the native-linux-builder feature to be granted for the FlakeHub account.
          # mkDefault so that builders.nix can turn it off in favor of the OrbStack VM.
          # https://determinate.systems/blog/changelog-determinate-nix-384/
          builder.state = lib.mkDefault "enabled";
        };
      };
      environment.etc."nix/nix.custom.conf".text = ''
        !include nix.secrets.conf
      '';
      nix.enable = false;
    };

  flake.modules.homeManager.standalone =
    { pkgs, ... }:
    {
      nix = {
        package = pkgs.determinate-nix;
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };
      };
    };

  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages =
        with pkgs;
        [
          nixpkgs-review
          nix-eval-jobs
          nix-output-monitor
          nix-fast-build
          nix-info
          fh
          nh
        ]
        ++ lib.optionals config.custom.features.extras.enable [
          nixd
          nixf-diagnose
          nixfmt-rs
          nix-update
          nurl
          hydra-check
          nixos-render-docs
          nix-converter
          nix-sweep
        ];
      custom.commands =
        let
          nix = lib.getExe pkgs.determinate-nix;
          jq = lib.getExe config.programs.jq.package;
        in
        {
          gc = /* bash */ ''
            systemProfiles="$(find "/nix/var/nix/profiles" -type l -lname '*link*')"
            userProfiles="$(find "${config.xdg.stateHome}/nix/profiles" -type l -lname '*link*')"

            if [ -z "$systemProfiles" ]; then
              systemProfilesAnswer="n"
            else
              echo "Do you want to clean the following system profiles? (y/n)"
              echo "$systemProfiles"
              read -r -n 1 systemProfilesAnswer
              echo
            fi

            if [ -z "$userProfiles" ]; then
              userProfilesAnswer="n"
            else
              echo "Do you want to clean the following user profiles? (y/n)"
              echo "$userProfiles"
              read -r -n 1 userProfilesAnswer
              echo
            fi

            if [ "$systemProfilesAnswer" = "y" ]; then
              for profile in $systemProfiles; do
                echo "Processing profile $profile..."
                sudo ${nix} profile wipe-history --older-than 7d --profile "$profile"
              done
            fi

            if [ "$userProfilesAnswer" = "y" ]; then
              for profile in $userProfiles; do
                echo "Processing profile $profile..."
                ${nix} profile wipe-history --older-than 7d --profile "$profile"
              done
            fi

            echo "Collecting garbage..."
            ${nix} store gc
            echo "Optimising store..."
            ${nix} store optimise
          '';
          flakeup = /* bash */ ''
            exec ${nix} flake update --commit-lock-file "$@"
          '';
          dev = /* bash */ ''
            exec ${nix} develop "$@"
          '';
          # Resolves the flake from the working directory, so run it in a checkout.
          nixrepl = /* bash */ ''
            exec ${nix} repl --expr 'rec {
              self = builtins.getFlake ("git+file://" + toString ./.);
              pkgs = import <pkgs> {
                overlays = [ self.overlays.default ];
                config = self.nixpkgsConfig;
              };
              lib = pkgs.lib;
            }' "$@"
          '';
          prefetch-attr = /* bash */ ''
            if [ "$#" -lt 1 ]; then
              echo "Usage: $0 NIX_FLAKE_ATTR [NIX_PREFETCH_ARGS...]" >&2
              exit 1
            fi
            value="$(${nix} eval --raw "$1")"
            shift
            hash="$(${nix} store prefetch-file --json "$@" "$value" | ${jq} -r .hash)"
            echo "hash = \"$hash\";"
          '';
          prefetch-attrs = /* bash */ ''
            if [ "$#" -lt 1 ]; then
              echo "Usage: $0 NIX_FLAKE_ATTRS [NIX_PREFETCH_ARGS...]" >&2
              exit 1
            fi
            TMPFILE="$(mktemp)"
            attrs="$1"
            shift
            echo "hashes = {" >> "$TMPFILE"
            ${nix} eval --json "$attrs" \
              | ${jq} -r 'to_entries[] | "\(.key) \(.value)"' \
              | while read -r key value; do
                echo "Evaluating $key" >&2
                hash="$(${nix} store prefetch-file --json "$@" "$value" | ${jq} -r .hash)"
                echo "  $key = \"$hash\";" >> "$TMPFILE"
              done
            echo "};" >> "$TMPFILE"
            cat "$TMPFILE"
            rm "$TMPFILE"
          '';
          nix-flake-input = /* bash */ ''
            if [ "$#" -lt 1 ]; then
              echo "Usage: $0 INPUT_NAME [NIX_FLAKE_PREFETCH_ARGS...]" >&2
              exit 1
            fi
            input="$1"
            shift
            ${nix} flake prefetch --inputs-from . "$input" --json "$@" | ${jq} -r .storePath
          '';
        };
    };
}
