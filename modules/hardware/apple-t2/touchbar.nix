# The Touch Bar, drawn by upstream's daemon instead of tiny-dfr. See
# `pkgs/by-name/kait2en/touchbar.nix`. The package's udev rules start the
# attach unit at boot and after resume.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.apple-t2.touchbar;
      package = pkgs.kait2en.touchbar;
      settingsFormat = pkgs.formats.toml { };
      # Named by the udev rules.
      group = "kait2en-touchbar";
    in
    {
      options.custom.apple-t2.touchbar = {
        enable = lib.mkEnableOption "the Apple T2 Touch Bar daemon";

        settings = lib.mkOption {
          inherit (settingsFormat) type;
          default = { };
          description = ''
            Overrides of the defaults in upstream's `config/touchbar.toml`.
            A personal `~/.config/kait2en-touchbar/config.toml` replaces them.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # The CLI inspects and resets the learned timeouts.
        environment.systemPackages = [ package ];
        environment.etc."kait2en/touchbar.toml" = lib.mkIf (cfg.settings != { }) {
          source = settingsFormat.generate "touchbar.toml" cfg.settings;
        };

        services.udev.packages = [ package ];
        services.upower.enable = true;
        systemd.packages = [ package ];
        systemd.user.services.kait2en-touchbar = {
          wantedBy = [ "graphical-session.target" ];
          path = [ config.services.pipewire.wireplumber.package ];
        };

        users.groups.${group} = { };
        users.users.${config.custom.user.login}.extraGroups = [ group ];
      };
    };
}
