# Broadcom Wi-Fi and Bluetooth across S3. See `pkgs/by-name/kait2en/suspend.nix`.
{
  flake.modules.nixos.apple-t2 =
    { pkgs, ... }:
    {
      systemd.packages = [ pkgs.kait2en.suspend ];
      systemd.services.kait2en-suspend.wantedBy = [ "sleep.target" ];
    };
}
