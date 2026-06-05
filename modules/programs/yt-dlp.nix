{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    lib.mkIf config.custom.features.withOptionals {
      programs.yt-dlp = {
        enable = true;
        settings = {
          embed-metadata = true;
          embed-thumbnail = true;
          no-playlist = true;
        };
      };
    };
}
