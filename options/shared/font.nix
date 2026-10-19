# Primary monospace font, shared across all module systems
# (nixos/darwin/home/nixvim) so that the standalone nixvim build can read it.
# The font itself is installed by modules/fonts and modules/environment/homebrew.nix.
{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.custom.font = {
    family = lib.mkOption {
      type = lib.types.str;
      default = "IosevkaTerm Nerd Font";
      description = "Family name of the primary monospace font used by terminals, editors, and desktops.";
    };

    size = lib.mkOption {
      type = lib.types.ints.positive;
      default = if pkgs.stdenv.hostPlatform.isDarwin then 14 else 12;
      description = "Point size of the primary monospace font, larger on darwin to match its rendering.";
    };

    familyUnderscored = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = lib.replaceStrings [ " " ] [ "_" ] config.custom.font.family;
      description = "Family name with spaces replaced by underscores, as expected by the guifont option of Neovim.";
    };
  };
}
