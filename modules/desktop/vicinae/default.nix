# Vicinae: a native, fast, extensible launcher (Raycast-like) available across
# every Linux desktop. Runs as a user systemd service that autostarts with the
# graphical session. https://docs.vicinae.com/nixos
{
  flake.modules.nixos.base =
    { config, ... }:
    {
      programs.vicinae.input-server.enable = config.custom.features.graphical.enable;
    };

  flake.modules.homeManager.default =
    {
      lib,
      pkgs,
      config,
      inputs,
      osConfig,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      vicinaeExtensions = inputs.vicinae-extensions.packages.${system};

      # Vicinae has no options for shortcuts and snippets yet, so write its data
      # files directly. Both are lists keyed by an opaque id, and every field
      # below that we do not set has a usable default in vicinae.
      mkId = prefix: name: "${prefix}-${lib.replaceStrings [ " " ] [ "-" ] name}";

      # `app` names the program that opens the link, "default" being the system
      # default opener for its scheme.
      mkShortcut =
        name: shortcut:
        {
          inherit name;
          id = mkId "sct" name;
          app = "default";
        }
        // shortcut;

      # `data` is a union discriminated by its key, `{ file = ...; }` being the
      # other variant.
      mkSnippet = name: { keyword, text }: {
        inherit name;
        id = mkId "snp" name;
        data.text = text;
        expansion.keyword = keyword;
      };

      dataFile =
        name: mkEntry: entries:
        (pkgs.formats.json { }).generate "vicinae-${name}.json" (lib.mapAttrsToList mkEntry entries);
    in
    lib.mkIf config.custom.features.graphical.enable {
      xdg.dataFile = {
        "vicinae/shortcuts/shortcuts.json".source = dataFile "shortcuts" mkShortcut (
          import ./_shortcuts.nix
        );
        "vicinae/snippets/snippets.json".source = dataFile "snippets" mkSnippet (import ./_snippets.nix);
      };

      programs.vicinae = {
        enable = true;
        package =
          if pkgs.stdenv.hostPlatform.isDarwin && osConfig ? homebrew then
            pkgs.writeShellScriptBin "vicinae" ''
              exec ${osConfig.homebrew.prefix}/bin/vicinae "$@"
            ''
          else
            pkgs.vicinae;

        systemd.enable = true;
        launchd.enable = false;

        extensions =
          (with vicinaeExtensions; [
            github
            nix
          ])
          ++ (with pkgs.raycastExtensions; [
            _1password
          ]);

        settings = {
          theme = {
            dark.name = "gruvbox-dark";
            light.name = "gruvbox-light";
          };
          font.normal.family = "Inter";
        };
      };
    };
}
