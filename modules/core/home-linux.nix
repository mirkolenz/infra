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
        custom.commands.getusers = /* bash */ ''
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
      lib.mkIf config.custom.features.graphical.enable {
        home.packages = with pkgs; [
          anydesk
          obsidian
          zotero
          teams-for-linux
          stamp
          todoist-electron
          libreoffice-stable
          # papers ships with the GNOME core apps but not with Cosmic
          papers
          # the desktop build bundles the server, so it needs no separate host
          stirling-pdf-desktop
        ];
        home.file.".face".source = ./mlenz.jpg;
      }
    )
  ];
}
