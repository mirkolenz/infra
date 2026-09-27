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
      custom.commands =
        let
          mogrify = lib.getExe' pkgs.imagemagick "mogrify";
          ffmpeg = lib.getExe pkgs.ffmpeg;
        in
        {
          # https://masdilor.github.io/use-imagemagick-to-resize-and-compress-images/
          mogrify-convert = /* bash */ ''
            if [ "$#" -lt 2 ]; then
              echo "Usage: $0 QUALITY FILE..." >&2
              exit 1
            fi
            quality="$1"
            shift

            exec ${mogrify} -strip -interlace none -sampling-factor 4:2:0 -define jpeg:dct-method=float -quality "$quality" "$@"
          '';
          # https://masdilor.github.io/use-imagemagick-to-resize-and-compress-images/
          mogrify-resize = /* bash */ ''
            if [ "$#" -lt 3 ]; then
              echo "Usage: $0 QUALITY FINAL_SIZE FILE..." >&2
              exit 1
            fi
            quality="$1"
            shift
            final_size="$1"
            shift

            exec ${mogrify} -filter Triangle -define filter:support=2 -thumbnail "$final_size" -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality "$quality" -define jpeg:fancy-upsampling=off -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 -define png:exclude-chunk=all -interlace none -colorspace sRGB "$@"
          '';
          # Only raster images are touched, text and vector graphics pass through untouched.
          # The distiller presets such as /ebook are avoided on purpose: they force a full
          # sRGB color conversion of every object, which is both lossy and around 20x slower.
          # https://ghostscript.readthedocs.io/en/latest/VectorDevices.html
          pdfcompress = /* bash */ ''
            if [ "$#" -lt 1 ]; then
              echo "Usage: $0 FILE [GHOSTSCRIPT_ARGS...]" >&2
              echo "Env: PDFCOMPRESS_DPI (default 300), PDFCOMPRESS_QUALITY (default 1.5, 0.1 best to 3 worst)" >&2
              exit 1
            fi

            file="$1"
            shift

            dpi="''${PDFCOMPRESS_DPI:-300}"
            quality="''${PDFCOMPRESS_QUALITY:-1.5}"

            # The JPEG quality factor has no command line switch and is only reachable
            # through the PostScript distiller parameters evaluated by -c.
            imagedict="<</QFactor $quality /Blend 1>>"

            tmpfile="$(mktemp)"
            trap 'rm -f "$tmpfile"' EXIT

            ${lib.getExe pkgs.ghostscript} \
              -dNOPAUSE -dQUIET -dBATCH -dSAFER \
              -sDEVICE=pdfwrite \
              -dCompatibilityLevel=1.7 \
              -dAutoRotatePages=/None \
              -dDownsampleColorImages=true \
              -dColorImageDownsampleType=/Bicubic \
              -dColorImageResolution="$dpi" \
              -dDownsampleGrayImages=true \
              -dGrayImageDownsampleType=/Bicubic \
              -dGrayImageResolution="$dpi" \
              -dDownsampleMonoImages=true \
              -dMonoImageResolution="$((dpi * 2))" \
              "$@" \
              -sOutputFile="$tmpfile" \
              -c "<</ColorACSImageDict $imagedict /GrayACSImageDict $imagedict>> setdistillerparams" \
              -f "$file"

            if [ "$(wc -c < "$tmpfile")" -lt "$(wc -c < "$file")" ]; then
              cat "$tmpfile" > "$file"
            else
              echo "Compression did not shrink $file, keeping the original" >&2
            fi
          '';
          fontconvert = /* bash */ ''
            if [ "$#" -lt 2 ]; then
              echo "Usage: $0 SOURCE TARGET [FONTFORGE_ARGS...]" >&2
              exit 1
            fi
            source="$1"
            shift
            target="$1"
            shift
            exec ${lib.getExe' pkgs.fontforge "fontforge"} -c "Open(\"$source\"); Generate(\"$target\");" "$@"
          '';
          ffmpeg2web = /* bash */ ''
            if [ "$#" -lt 1 ]; then
              echo "Usage: $0 INPUT_FILE [FFMPEG_ARGS...]" >&2
              exit 1
            fi

            input="$1"
            shift

            exec ${ffmpeg} -i "$input" \
              -vf "scale='min(1920,iw)':-2:flags=lanczos" \
              -c:v libx264 \
              -preset veryslow \
              -profile:v high \
              -pix_fmt yuv420p \
              -c:a aac \
              -b:a 128k \
              -ac 2 \
              -movflags \
              +faststart \
              "$@"
          '';
          ffmpeg2poster = /* bash */ ''
            if [ "$#" -lt 1 ]; then
              echo "Usage: $0 INPUT_FILE [FFMPEG_ARGS...] OUTPUT_FILE" >&2
              echo "Pass -ss SECONDS to skip black intros longer than the 300 analyzed frames" >&2
              exit 1
            fi

            input="$1"
            shift

            exec ${ffmpeg} -i "$input" \
              -vf "thumbnail=300,scale='min(1920,iw)':-2:flags=lanczos" \
              -frames:v 1 \
              -update 1 \
              -q:v 2 \
              "$@"
          '';
        };
    };
}
