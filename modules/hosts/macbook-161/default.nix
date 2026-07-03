{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.macbook-161.module =
    {
      pkgs,
      ...
    }:
    {
      imports = [
        nixos.default
        "${inputs.nixos-hardware}/apple"
        "${inputs.nixos-hardware}/apple/t2"
        "${inputs.nixos-hardware}/common/cpu/intel/coffee-lake/cpu-only.nix"
        "${inputs.nixos-hardware}/common/pc/laptop"
        "${inputs.nixos-hardware}/common/pc/ssd"
      ];
      nixpkgs.hostPlatform = "x86_64-linux";

      custom.features = {
        graphical.desktopManager = "cosmic";
        extras.enable = true;
      };

      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
        efi.efiSysMountPoint = "/boot";
      };

      swapDevices = [
        {
          device = "/swapfile";
          size = 4 * 1024;
        }
      ];

      boot.kernelParams = [
        "i915.modeset=0"
      ];

      systemd.sleep.settings.Sleep = {
        AllowSuspend = "no";
        AllowHibernation = "no";
        AllowSuspendThenHibernate = "no";
        AllowHybridSleep = "no";
      };

      services.logind.settings.Login = {
        HandleLidSwitch = "lock";
        HandleLidSwitchExternalPower = "lock";
        HandleLidSwitchDocked = "ignore";
      };

      # https://wiki.t2linux.org/guides/postinstall/
      # https://github.com/NixOS/nixos-hardware/blob/master/apple/t2/default.nix
      hardware.apple-t2 = {
        enableIGPU = false;
        kernelChannel = "latest";
        firmware.enable = false;
      };
      hardware.apple-t2-firmware.enable = true;

      # The T2 chip exposes an internal USB ethernet interface with no Linux support.
      # Keep it down in networkd and hide it from NetworkManager.
      # https://wiki.t2linux.org/guides/postinstall/
      systemd.network.networks."10-t2-ethernet" = {
        matchConfig.MACAddress = "ac:de:48:00:11:22";
        linkConfig = {
          ActivationPolicy = "manual";
          RequiredForOnline = false;
        };
      };
      networking.networkmanager.unmanaged = [ "mac:ac:de:48:00:11:22" ];

      # The AMD dGPU runs as the sole display device since the Intel iGPU is disabled.
      # Constrain it to low power mode to prevent overheating and unexpected shutdowns.
      # https://wiki.t2linux.org/guides/hybrid-graphics/
      services.udev.extraRules = /* bash */ ''
        SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="low"
      '';

      environment.systemPackages = with pkgs; [
        brightnessctl
      ];

      # https://github.com/AsahiLinux/tiny-dfr/blob/master/share/tiny-dfr/config.toml
      hardware.apple.touchBar = {
        enable = true;
        settings = {
          MediaLayerDefault = true;
        };
      };
    };
}
