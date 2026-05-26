{
  lib,
  config,
  pkgs,
  ...
}:
lib.mkIf config.custom.features.withDisplay {
  custom.nix.settings.trusted-users = [ "@wheel" ];

  services = {
    desktopManager.cosmic.enable = true;
    displayManager.cosmic-greeter.enable = true;
    system76-scheduler.enable = true;
    xserver = {
      enable = true;
      excludePackages = with pkgs; [ xterm ];
    };
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  programs = {
    _1password-gui.enable = true;
    nix-ld.enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  security.rtkit.enable = config.services.pipewire.enable;

  hardware = {
    graphics.enable = true;
    facetimehd.withCalibration = true;
  };

  services.mbpfan = {
    enable = false;
    aggressive = false;
  };

  # there is an issue with wpa_supplicant and broadcom-wl (used in Macs)
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };

  services.logind.settings.Login = lib.mkDefault {
    HandleLidSwitch = "sleep";
    HandleLidSwitchExternalPower = "sleep";
    HandleLidSwitchDocked = "ignore";
  };

  systemd.sleep.settings.Sleep = lib.mkDefault {
    AllowSuspend = "yes";
    AllowHibernation = "no";
    AllowSuspendThenHibernate = "no";
    AllowHybridSleep = "no";
  };
}
