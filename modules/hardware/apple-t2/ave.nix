# The T2's audio/video engine. See `pkgs/by-name/kait2en/ave.nix`.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.custom.apple-t2.ave.enable = lib.mkEnableOption "the Apple T2 audio and video engine";

      config = lib.mkIf config.custom.apple-t2.ave.enable {
        custom.apple-t2.bridge = {
          enable = true;
          packages = [ pkgs.kait2en.ave ];
          services = [ "kait2en-t2-remote" ];
        };
      };
    };
}
