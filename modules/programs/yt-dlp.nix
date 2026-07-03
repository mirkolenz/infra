{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    lib.mkIf config.custom.features.extras.enable {
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
