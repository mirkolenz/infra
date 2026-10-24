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
        icon = "web-browser";
      }
    ) config.custom.websites;
  };
}
