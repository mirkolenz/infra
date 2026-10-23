# Security hardening: NixOS sudo/kernel + darwin pam/sudo.
{
  flake.modules.nixos.base = {
    # https://wiki.nixos.org/wiki/NixOS_Hardening
    security = {
      sudo-rs = {
        enable = true;
        execWheelOnly = true;
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
