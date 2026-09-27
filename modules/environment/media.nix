{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.packages = with pkgs; [
        # images
        imagemagick
        pngquant
        vtracer
        exiftool
        # video
        ffmpeg
        ffmpeg-normalize
        # pdf
        ghostscript
        qpdf
        poppler-utils
        pstoedit
        unpaper
        # fonts
        fontforge
      ];
    };
}
