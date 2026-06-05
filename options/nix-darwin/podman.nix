{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.virtualisation.podman;
  tomlFormat = pkgs.formats.toml { };
  jsonFormat = pkgs.formats.json { };
in
{
  options.virtualisation.podman = {
    enable = lib.mkEnableOption "Podman";

    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/virtualisation/containers.nix
    containersConf = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = "containers.conf configuration";
    };

    storageConf = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = "storage.conf configuration";
    };

    registries = {
      search = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "docker.io"
        ];
        description = ''
          List of repositories to search.
        '';
      };
      insecure = lib.mkOption {
        default = [ ];
        type = lib.types.listOf lib.types.str;
        description = ''
          List of insecure repositories.
        '';
      };
      block = lib.mkOption {
        default = [ ];
        type = lib.types.listOf lib.types.str;
        description = ''
          List of blocked repositories.
        '';
      };
    };

    policy = lib.mkOption {
      default = { };
      type = jsonFormat.type;
      description = ''
        Signature verification policy file.
        If this option is empty the default policy file from
        `skopeo` will be used.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      podman
    ];

    virtualisation.podman.storageConf.storage = {
      driver = lib.mkDefault "overlay";
      graphroot = lib.mkDefault "/var/lib/containers/storage";
      runroot = lib.mkDefault "/run/containers/storage";
    };

    environment.etc = {
      "containers/containers.conf".source = tomlFormat.generate "containers.conf" cfg.containersConf;
      "containers/storage.conf".source = tomlFormat.generate "storage.conf" cfg.storageConf;

      "containers/registries.conf".source = tomlFormat.generate "registries.conf" {
        registries = lib.mapAttrs (n: v: { registries = v; }) cfg.registries;
      };

      "containers/policy.json".source =
        if cfg.policy != { } then
          jsonFormat.generate "policy.json" cfg.policy
        else
          "${pkgs.skopeo.policy}/default-policy.json";
    };
  };
}
