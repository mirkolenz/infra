# Mirrors the client-side part of the NixOS module, see
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/virtualisation/podman/default.nix
# Podman on darwin is a remote client of the podman machine VM,
# so sockets, networks and pruning are configured inside the VM.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.virtualisation.podman;

  # Provides a fake "docker" binary mapping to podman
  dockerCompat = pkgs.runCommand "${cfg.package.pname}-docker-compat-${cfg.package.version}" {
    inherit (cfg.package) meta;
    preferLocalBuild = true;
  } "mkdir -p $out/bin && ln -s ${lib.getExe cfg.package} $out/bin/docker";
in
{
  options.virtualisation.podman = {
    enable = lib.mkEnableOption "Podman, a daemonless container engine";

    dockerCompat = lib.mkEnableOption "an alias mapping {command}`docker` to {command}`podman`";

    package = lib.mkPackageOption pkgs "podman" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ] ++ lib.optional cfg.dockerCompat dockerCompat;

    virtualisation.containers.enable = true;
  };
}
