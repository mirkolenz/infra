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
          mogrify-convert.text = /* bash */ ''
            # @describe Compress images in place
            # @arg quality!  Quality from 1 to 100
            # @arg files+    Images to overwrite

            exec ${mogrify} -strip -interlace none -sampling-factor 4:2:0 -define jpeg:dct-method=float -quality "$argc_quality" "''${argc_files[@]}"
          '';
          # https://masdilor.github.io/use-imagemagick-to-resize-and-compress-images/
          mogrify-resize.text = /* bash */ ''
            # @describe Resize and compress images in place
            # @arg quality!     Quality from 1 to 100
            # @arg final-size!  Geometry of the thumbnail, such as 800x600
            # @arg files+       Images to overwrite

            exec ${mogrify} -filter Triangle -define filter:support=2 -thumbnail "$argc_final_size" -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality "$argc_quality" -define jpeg:fancy-upsampling=off -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 -define png:exclude-chunk=all -interlace none -colorspace sRGB "''${argc_files[@]}"
          '';
          # Only raster images are touched, text and vector graphics pass through untouched.
          # The distiller presets such as /ebook are avoided on purpose: they force a full
          # sRGB color conversion of every object, which is both lossy and around 20x slower.
          # https://ghostscript.readthedocs.io/en/latest/VectorDevices.html
          pdfcompress.text = /* bash */ ''
            # @describe Downsample the images of a PDF in place, keeping it if nothing shrinks
            # @arg file!
            # @arg ghostscript-args~                      Further arguments of ghostscript
            # @option --dpi=300 $PDFCOMPRESS_DPI          Resolution of color and gray images, doubled for monochrome ones
            # @option --quality=1.5 $PDFCOMPRESS_QUALITY  JPEG quality factor from 0.1 (best) to 3 (worst)

            # The JPEG quality factor has no command line switch and is only reachable
            # through the PostScript distiller parameters evaluated by -c.
            imagedict="<</QFactor $argc_quality /Blend 1>>"

            tmpfile="$(mktemp)"
            trap 'rm -f "$tmpfile"' EXIT

            ${lib.getExe pkgs.ghostscript} \
              -dNOPAUSE -dQUIET -dBATCH -dSAFER \
              -sDEVICE=pdfwrite \
              -dCompatibilityLevel=1.7 \
              -dAutoRotatePages=/None \
              -dDownsampleColorImages=true \
              -dColorImageDownsampleType=/Bicubic \
              -dColorImageResolution="$argc_dpi" \
              -dDownsampleGrayImages=true \
              -dGrayImageDownsampleType=/Bicubic \
              -dGrayImageResolution="$argc_dpi" \
              -dDownsampleMonoImages=true \
              -dMonoImageResolution="$((argc_dpi * 2))" \
              "''${argc_ghostscript_args[@]}" \
              -sOutputFile="$tmpfile" \
              -c "<</ColorACSImageDict $imagedict /GrayACSImageDict $imagedict>> setdistillerparams" \
              -f "$argc_file"

            if [ "$(wc -c < "$tmpfile")" -lt "$(wc -c < "$argc_file")" ]; then
              cat "$tmpfile" > "$argc_file"
            else
              echo "Compression did not shrink $argc_file, keeping the original" >&2
            fi
          '';
          fontconvert.text = /* bash */ ''
            # @describe Convert a font to the format given by the extension of the target
            # @arg source-file!
            # @arg target-file!
            # @arg fontforge-args~  Further arguments of fontforge

            exec ${lib.getExe' pkgs.fontforge "fontforge"} -c "Open(\"$argc_source_file\"); Generate(\"$argc_target_file\");" "''${argc_fontforge_args[@]}"
          '';
          ffmpeg2web.text = /* bash */ ''
            # @describe Encode a video for the web as H.264 of at most 1920 pixels width
            # @arg input-file!
            # @arg ffmpeg-args~  Further arguments of ffmpeg, ending with the output file

            exec ${ffmpeg} -i "$argc_input_file" \
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
              "''${argc_ffmpeg_args[@]}"
          '';
          ffmpeg2poster.text = /* bash */ ''
            # @describe Extract a representative frame of a video as poster image
            #
            # Pass -ss SECONDS to skip black intros longer than the 300 analyzed frames.
            # @arg input-file!
            # @arg ffmpeg-args~  Further arguments of ffmpeg, ending with the output file

            exec ${ffmpeg} -i "$argc_input_file" \
              -vf "thumbnail=300,scale='min(1920,iw)':-2:flags=lanczos" \
              -frames:v 1 \
              -update 1 \
              -q:v 2 \
              "''${argc_ffmpeg_args[@]}"
          '';
        };
    };
}
