# Web shortcuts, shared by the vicinae launcher and the Homer dashboard of the homelab.
# Values are assigned in modules/core/shortcuts.nix.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.custom.shortcuts = mkOption {
    default = { };
    description = "Web shortcuts keyed by their title.";
    type = types.attrsOf (
      types.submodule {
        options = {
          url = mkOption {
            type = types.str;
            description = "Static page of the shortcut, for clients that cannot fill in placeholders.";
          };
          query = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Link with vicinae placeholders that a launcher opens instead of `url`.
              https://docs.vicinae.com/shortcuts
            '';
          };
          favicon = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Domain whose favicon represents the shortcut in the launcher.";
          };
          icon = mkOption {
            type = types.str;
            description = "Font Awesome classes of the icon on the dashboard.";
            example = "fab fa-github";
          };
        };
      }
    );
  };
}
