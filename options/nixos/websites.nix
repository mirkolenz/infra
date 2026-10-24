{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.custom.websites = lib.mkOption {
    default = { };
    description = "Websites with a desktop shortcut that opens them in Firefox.";
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          options = {
            title = lib.mkOption {
              type = lib.types.str;
            };
            url = lib.mkOption {
              type = lib.types.str;
              example = "https://example.org";
            };
            allow = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "${config.url}/*" ];
              description = "Match patterns a website filter has to allow for the site.";
            };
            categories = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            icon = lib.mkOption {
              type = lib.types.str;
              default = "web-browser";
              description = "Name of a Papirus app icon, since Adwaita has no colored ones.";
            };
          };
        }
      )
    );
  };
  config = {
    environment.systemPackages = lib.mapAttrsToList (
      name: site:
      pkgs.makeDesktopItem {
        inherit name;
        inherit (site) categories;
        desktopName = site.title;
        exec = "firefox ${site.url}";
        # a copy spares the closure the whole theme
        icon = pkgs.runCommand "${site.icon}.svg" { } ''
          cp ${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/${site.icon}.svg $out
        '';
      }
    ) config.custom.websites;
  };
}
