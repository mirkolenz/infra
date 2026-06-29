{
  lib,
  stdenv,
  gdk-pixbuf,
  librsvg,
  prev,
}:
prev.pdfpc.overrideAttrs (oldAttrs: {
  # librsvg's SVG gdk-pixbuf loader is broken on Darwin: it is installed as a .dylib with a
  # build-sandbox install name and an unresolvable @rpath dependency, and
  # gdk-pixbuf-query-loaders only scans *.so, so the loader is missing from loaders.cache and
  # pdfpc cannot render its SVG icons ("Couldn't recognize the image file format").
  # Fixing librsvg itself would rebuild its whole reverse-dependency tree, so instead build a
  # fixed loader and cache inside pdfpc's own output and point its wrapper at it.
  # This runs in postInstall so the exported GDK_PIXBUF_MODULE_FILE is picked up by
  # wrapGAppsHook3, whose gappsWrapperArgsHook reads the variable during the fixup phase.
  postInstall =
    (oldAttrs.postInstall or "")
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      cacheDir=$out/share/pdfpc/pixbuf-loaders
      loader=$cacheDir/libpixbufloader-svg.so
      install -Dm755 ${librsvg}/${gdk-pixbuf.binaryDir}/loaders/libpixbufloader_svg.dylib "$loader"

      install_name_tool -id "$loader" "$loader"
      install_name_tool -change @rpath/librsvg-2.2.dylib ${librsvg}/lib/librsvg-2.2.dylib "$loader"

      ${lib.getDev gdk-pixbuf}/bin/gdk-pixbuf-query-loaders \
        ${lib.getLib gdk-pixbuf}/${gdk-pixbuf.binaryDir}/loaders/*.so \
        "$loader" > $cacheDir/loaders.cache

      export GDK_PIXBUF_MODULE_FILE=$cacheDir/loaders.cache
    '';

  passthru = oldAttrs.passthru // {
    updateScript = null;
  };

  meta = oldAttrs.meta // {
    hydraPlatforms = lib.platforms.darwin;
  };
})
