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
}
