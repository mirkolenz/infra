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
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      vicinaeExtensions = inputs.vicinae-extensions.packages.${system};
    in
    lib.mkIf config.custom.features.graphical.enable {
      programs.vicinae = {
        enable = true;
        package = if pkgs.stdenv.isDarwin then pkgs.writeShellScriptBin "vicinae" "true" else pkgs.vicinae;

        systemd = {
          enable = true;
          autoStart = true;
        };

        extensions =
          (with vicinaeExtensions; [
            nix
            zoxide-recent-directories
          ])
          ++ (with pkgs.raycastExtensions; [
            _1password
          ]);

        settings = {
          theme = {
            dark.name = "vicinae-dark";
            light.name = "vicinae-light";
          };
          font.normal.family = "Inter";

          # Layer shell gives the nicest overlay on wlroots/KWin compositors but is
          # unsupported on GNOME (Mutter) and X11 (XFCE), where a plain floating
          # window is the robust fallback.
          launcher_window.layer_shell.enabled = lib.elem config.custom.features.graphical.desktopManager [
            "cosmic"
            "plasma"
          ];
        };
      };
    };
}
