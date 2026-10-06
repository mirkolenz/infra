# NixOS base profile: core system settings, base programs, auto-upgrade and the
# always-on/server tweaks (nixos.base), plus the full-system packages
# (nixos.default). Foundational config that is not a distinct feature domain.
{
  flake.modules.nixos.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      system.stateVersion = config.custom.stateVersions.linux;

      services.fwupd.enable = true;

      systemd.enableStrictShellChecks = true;

      documentation = {
        nixos.enable = false;
        # this is slow
        man.cache.enable = false;
      };

      hardware.enableAllFirmware = true;

      environment.variables.BROWSER = lib.mkIf (!config.custom.features.graphical.enable) "echo";

      environment.systemPackages = with pkgs; [
        pciutils
        ghostty.terminfo
      ];

      programs = {
        git.enable = true;
        neovim = {
          enable = true;
          viAlias = true;
          vimAlias = true;
        };
      };

      system.autoUpgrade = {
        flake = "github:mirkolenz/infra";
        upgrade = false;
        dates = "04:00";
        allowReboot = true;
        runGarbageCollection = true;
        rebootWindow = {
          lower = "04:00";
          upper = "05:00";
        };
        # only unattended on always-on hosts
        enable = lib.mkIf config.custom.features.unattended.enable true;
      };

      systemd.sleep.settings.Sleep = lib.mkIf config.custom.features.unattended.enable {
        AllowSuspend = lib.mkDefault "no";
        AllowHibernation = lib.mkDefault "no";
        AllowSuspendThenHibernate = lib.mkDefault "no";
        AllowHybridSleep = lib.mkDefault "no";
      };
    };

  flake.modules.nixos.default =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        strace
      ];
    };
}
