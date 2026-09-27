# Nix wiring across home-manager, nixos and darwin: GC, store optimisation,
# determinate hookup, the secrets include and the nix tooling.
# The settings attrsets themselves live in settings.nix.
{
  flake.modules.nixos.base =
    { lib, pkgs, ... }:
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
    };
}
