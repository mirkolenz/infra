# Nix wiring across home-manager, nixos and darwin: GC, store optimisation,
# determinate hookup, the secrets include and the nix tooling.
# The settings attrsets themselves live in settings.nix.
let
  # Age of the profile generations that garbage collection deletes.
  gcAge = "7d";
in
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
          options = "--delete-older-than ${gcAge}";
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
          options = "--delete-older-than ${gcAge}";
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
    let
      nix = lib.getExe pkgs.determinate-nix;
      jq = lib.getExe config.programs.jq.package;
    in
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
      custom.bump.nix = {
        pathspecs = [ "flake.lock" ];
        text = "${nix} flake update --commit-lock-file";
      };
      custom.commands = {
        gc.text = /* bash */ ''
          # @describe Wipe the history of nix profiles, then collect and optimise the store
          # @option --older-than=${gcAge}  Age of the profile generations to delete
          # @flag -y --yes           Wipe the history without asking

          # Wipes the profiles below a directory with the nix command that follows it.
          wipe() {
            profiles="$(find "$1" -type l -lname '*link*')"

            if [ -z "$profiles" ]; then
              return
            fi

            answer="''${argc_yes:+y}"

            if [ -z "$answer" ]; then
              echo "Do you want to clean the following profiles? (y/n)"
              echo "$profiles"
              read -r -n 1 answer
              echo
            fi

            if [ "$answer" != "y" ]; then
              return
            fi

            for profile in $profiles; do
              echo "Processing profile $profile..."
              "''${@:2}" profile wipe-history --older-than "$argc_older_than" --profile "$profile"
            done
          }

          wipe /nix/var/nix/profiles sudo ${nix}
          wipe "${config.xdg.stateHome}/nix/profiles" ${nix}

          echo "Collecting garbage..."
          ${nix} store gc
          echo "Optimising store..."
          ${nix} store optimise
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
          # @describe Print the hash of the file at the URL of a flake attribute, or the hashes of an attribute set of URLs
          # @arg attr!               Flake attribute holding the URL or URLs
          # @arg nix-prefetch-args~  Further arguments of nix store prefetch-file

          prefetch() {
            ${nix} store prefetch-file --json "''${argc_nix_prefetch_args[@]}" "$1" | ${jq} -r .hash
          }

          value="$(${nix} eval --json "$argc_attr")"

          if url="$(${jq} -er strings <<<"$value")"; then
            hash="$(prefetch "$url")"
            echo "hash = \"$hash\";"
            exit
          fi

          # Prefetches all URLs in parallel, each into the file of its index, and prints them in order.
          dir="$(mktemp -d)"
          trap 'rm -rf "$dir"' EXIT
          ${jq} -r 'to_entries[] | "\(.key) \(.value)"' <<<"$value" > "$dir/entries"
          keys=()
          pids=()

          while read -r key url; do
            echo "Prefetching $key" >&2
            prefetch "$url" > "$dir/''${#keys[@]}" &
            keys+=("$key")
            pids+=("$!")
          done < "$dir/entries"

          echo "hashes = {"

          for i in "''${!keys[@]}"; do
            wait "''${pids[$i]}"
            echo "  ''${keys[$i]} = \"$(<"$dir/$i")\";"
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
