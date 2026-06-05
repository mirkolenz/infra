# https://github.com/nix-community/home-manager/blob/master/modules/misc/xdg.nix
# https://specifications.freedesktop.org/basedir/latest/
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.xdg;

  fileType =
    (import "${inputs.home-manager}/modules/lib/file-type.nix" {
      inherit (config.home) homeDirectory;
      inherit lib pkgs;
    }).fileType;
in
{
  options.xdg = {
    binFile = lib.mkOption {
      type = fileType "xdg.binFile" "{var}`xdg.binHome`" cfg.binHome;
      default = { };
      description = ''
        Attribute set of files to link into the user's XDG bin home.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      file = lib.mapAttrs' (name: file: lib.nameValuePair "${cfg.binHome}/${name}" file) cfg.binFile;
    };
  };
}
