# Linux home-manager profile: base packages and the desktop applications.
# The desktop environments themselves live in modules/desktop/{cosmic,gnome,xfce}.nix
# (cross-class), selected by custom.features.desktop.
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
          # https://unix.stackexchange.com/a/617686
          (writeShellApplication {
            name = "getusers";
            text = /* bash */ ''
              ${lib.getExe' procps "ps"} -eo user,uid | ${lib.getExe gawk} 'NR>1 && $2 >= 1000 && ++seen[$2]==1{print $1}'
            '';
          })
        ];
      }
    )

    (
      {
        pkgs,
        lib,
        config,
        ...
      }:
      lib.mkIf config.custom.features.withDisplay {
        home.packages =
          with pkgs;
          [
            anydesk
            firefox
            obsidian
            teams-for-linux
            vivaldi
            zotero
          ]
          ++ lib.optionals (pkgs.stdenv.hostPlatform.isx86_64) [
            google-chrome
            zoom-us
          ];
        home.file.".face".source = ./mlenz.jpg;
      }
    )
  ];
}
