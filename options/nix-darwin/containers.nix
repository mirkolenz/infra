# Mirrors the client-side part of the NixOS module, see
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/virtualisation/containers.nix
# Storage, CNI plugins and hooks belong to the podman machine VM.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.virtualisation.containers;
  toml = pkgs.formats.toml { };
  json = pkgs.formats.json { };
in
{
  options.virtualisation.containers = {
    enable = lib.mkEnableOption "the common /etc/containers configuration";

    containersConf.settings = lib.mkOption {
      type = toml.type;
      default = { };
      description = "containers.conf configuration";
    };

    registries.settings = lib.mkOption {
      type = toml.type;
      default = {
        registry = [
          { location = "docker.io"; }
          { location = "quay.io"; }
        ];
      };
      description = ''
        registries.conf configuration.
        https://github.com/containers/image/blob/main/docs/containers-registries.conf.5.md
      '';
    };

    policy = lib.mkOption {
      type = json.type;
      default = { };
      description = ''
        Signature verification policy file.
        If this option is empty the default policy file from `skopeo` is used.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc = {
      "containers/containers.conf".source = toml.generate "containers.conf" cfg.containersConf.settings;
      "containers/registries.conf".source = toml.generate "registries.conf" cfg.registries.settings;
      "containers/policy.json".source =
        if cfg.policy != { } then
          json.generate "policy.json" cfg.policy
        else
          "${pkgs.skopeo.policy}/default-policy.json";
    };
  };
}
