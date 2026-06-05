# Standalone home-manager only: always-on default, auto-upgrade timer and the
# generic Linux sudo PATH shim. Nix daemon config lives in modules/nix.
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
    in
    {
      custom.features.withAlwaysOn = lib.mkDefault true;

      custom.autoUpgrade = {
        enable = true;
        flake = "github:mirkolenz/infra";
      };

      home.shellAliases = {
        sudo = lib.mkIf config.targets.genericLinux.enable ''/usr/bin/sudo env "PATH=${sudoPath}"'';
      };
    };
}
