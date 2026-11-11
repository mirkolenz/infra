# Linux home-manager profile: base packages and the desktop applications.
# The desktop environments themselves live in modules/desktop/{cosmic,gnome,xfce}.nix
# (cross-class), selected by custom.features.graphical.desktopManager.
{
  flake.modules.homeManager.linux.imports = [
    (
      {
        pkgs,
        lib,
        ...
      }:
      {
        home.packages = with pkgs; [
          angrr
          cfspeedtest
        ];
        # https://unix.stackexchange.com/a/617686
        custom.commands.getusers.text = /* bash */ ''
          # @describe List the regular users that run processes

          ${lib.getExe' pkgs.procps "ps"} -eo user,uid | ${lib.getExe pkgs.gawk} 'NR>1 && $2 >= 1000 && ++seen[$2]==1{print $1}'
        '';
      }
    )

    (
      {
        pkgs,
        lib,
        config,
        ...
      }:
      let
        inherit (config.custom.features.graphical) displayServer;
      in
      lib.mkIf config.custom.features.graphical.enable {
        home.packages =
          with pkgs;
          [
            obsidian
            zotero
            teams-for-linux
            stamp
            todoist-electron
            # papers ships with the GNOME core apps but not with Cosmic
            papers
            # page operations, which papers lacks
            pdfarranger
          ]
          # clipboard access for terminal programs such as neovim and helix
          ++
            lib.optional (displayServer != null)
              {
                wayland = wl-clipboard;
                xserver = xclip;
              }
              .${displayServer};
        # macOS caffeinate, keeping the system awake while the command typed after it runs
        programs.fish.shellAbbrs.caffeinate = lib.mkDefault "systemd-inhibit --what=sleep";
        programs.libreoffice = {
          enable = true;
          package = pkgs.libreoffice-stable;
        };
        home.file.".face".source = ./mlenz.jpg;
      }
    )
  ];
}
