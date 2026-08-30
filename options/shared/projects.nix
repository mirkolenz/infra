# Home-relative location of checked out repositories, shared across all module
# systems (nixos/darwin/home/nixvim). Only the name is shared because nixvim has
# no notion of a home directory; homes turn it into an absolute path via
# custom.projectsPath in options/home-manager/custom.nix.
{ lib, pkgs, ... }:
{
  options.custom.projectsDir = lib.mkOption {
    type = lib.types.str;
    default = if pkgs.stdenv.hostPlatform.isDarwin then "Developer" else "Projects";
    description = ''
      Directory below the home directory holding checked out repositories,
      grouped by owner. Matches the Developer directory on darwin and
      XDG_PROJECTS_DIR, added in xdg-user-dirs 0.20, everywhere else.
    '';
  };
}
