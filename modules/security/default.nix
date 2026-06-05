# Security hardening: NixOS sudo/kernel + darwin pam/sudo.
{
  flake.modules.nixos.base =
    { config, ... }:
    {
      # https://wiki.nixos.org/wiki/NixOS_Hardening
      security = {
        sudo = {
          execWheelOnly = true;
        };
        sudo-rs = {
          enable = true;
          inherit (config.security.sudo) execWheelOnly wheelNeedsPassword;
        };
        protectKernelImage = true;
        lockKernelModules = false;
      };
    };

  flake.modules.darwin.base = {
    security = {
      pam.services.sudo_local = {
        enable = true;
        reattach = true;
        touchIdAuth = true;
        watchIdAuth = true;
      };
      sudo.extraConfig = ''
        Defaults env_keep -= "HOME"
        Defaults pwfeedback
      '';
    };
  };
}
