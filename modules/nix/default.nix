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
        needs-reboot.text = /* bash */ ''
          # @describe Check whether the built system has a different kernel than the booted one

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
        nixos-profile.text = /* bash */ ''
          # @describe Run a nix profile command on the system profile
          # @arg command!  Subcommand of nix profile
          # @arg nix-args~ Further arguments of nix profile

          exec ${lib.getExe config.nix.package} profile "$argc_command" --profile /nix/var/nix/profiles/system "''${argc_nix_args[@]}"
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
          gc.text = /* bash */ ''
            # @describe Wipe the history of nix profiles older than a week, then collect and optimise the store

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
          flakeup.text = /* bash */ ''
            # @describe Update the flake inputs and commit the lock file
            # @arg args~ Arguments of nix flake update

            exec ${nix} flake update --commit-lock-file "$@"
          '';
          dev.text = /* bash */ ''
            # @describe Enter the development shell of a flake
            # @arg args~ Arguments of nix develop

            exec ${nix} develop "$@"
          '';
          nixrepl.text = /* bash */ ''
            # @describe Open a nix repl with the flake of the working directory and its packages
            # @arg args~ Arguments of nix repl

            exec ${nix} repl --expr 'rec {
              self = builtins.getFlake ("git+file://" + toString ./.);
              pkgs = import <pkgs> {
                overlays = [ self.overlays.default ];
                config = self.nixpkgsConfig;
              };
              lib = pkgs.lib;
            }' "$@"
          '';
          prefetch-attr.text = /* bash */ ''
            # @describe Print the hash of the file at the URL of a flake attribute
            # @arg attr!               Flake attribute holding the URL
            # @arg nix-prefetch-args~  Further arguments of nix store prefetch-file

            url="$(${nix} eval --raw "$argc_attr")"
            hash="$(${nix} store prefetch-file --json "''${argc_nix_prefetch_args[@]}" "$url" | ${jq} -r .hash)"
            echo "hash = \"$hash\";"
          '';
          prefetch-attrs.text = /* bash */ ''
            # @describe Print the hashes of the files at the URLs of a flake attribute set
            # @arg attr!               Flake attribute holding the URLs
            # @arg nix-prefetch-args~  Further arguments of nix store prefetch-file

            echo "hashes = {"
            ${nix} eval --json "$argc_attr" \
              | ${jq} -r 'to_entries[] | "\(.key) \(.value)"' \
              | while read -r key url; do
                echo "Evaluating $key" >&2
                hash="$(${nix} store prefetch-file --json "''${argc_nix_prefetch_args[@]}" "$url" | ${jq} -r .hash)"
                echo "  $key = \"$hash\";"
              done
            echo "};"
          '';
          nix-flake-input.text = /* bash */ ''
            # @describe Print the store path of an input of the flake in the working directory
            # @arg input!     Name of the flake input
            # @arg nix-args~  Further arguments of nix flake prefetch

            ${nix} flake prefetch --inputs-from . "$argc_input" --json "''${argc_nix_args[@]}" | ${jq} -r .storePath
          '';
        };
    };
}
