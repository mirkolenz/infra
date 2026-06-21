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

      services.printing.enable = false;

      systemd.enableStrictShellChecks = true;

      documentation = {
        nixos.enable = false;
        # this is slow
        man.cache.enable = false;
      };

      boot.loader = {
        generic-extlinux-compatible.configurationLimit = 10;
        grub.configurationLimit = 10;
        systemd-boot.configurationLimit = 10;
      };
      boot.binfmt.preferStaticEmulators = true;

      hardware.enableAllFirmware = true;

      zramSwap = {
        enable = true;
        memoryPercent = 100;
        memoryMax = 8 * 1024 * 1024 * 1024;
      };

      environment.variables.BROWSER = lib.mkIf (!config.custom.features.withDisplay) "echo";

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
          lower = "03:30";
          upper = "05:00";
        };
        # only unattended on always-on hosts
        enable = lib.mkIf config.custom.features.withAlwaysOn true;
      };

      systemd.sleep.settings.Sleep = lib.mkIf config.custom.features.withAlwaysOn (
        lib.mkDefault {
          AllowSuspend = "no";
          AllowHibernation = "no";
          AllowSuspendThenHibernate = "no";
          AllowHybridSleep = "no";
        }
      );
    };

  flake.modules.nixos.default =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        strace
      ];
    };
}
