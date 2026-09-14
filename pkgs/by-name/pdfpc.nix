{
  lib,
  stdenv,
  prev,
}:
prev.pdfpc.overrideAttrs (oldAttrs: {
  # The presenter shrinks its bottom row by the amount it overshoots the window height, but the
  # correction is unbounded: once the slide area alone is as tall as the window, the resulting
  # height turns negative and is handed to the SVG icon renderer, the bottom-text CSS and the
  # paned allocation, yielding "Invalid rectangle passed" from pixman plus GTK size warnings.
  postPatch =
    (oldAttrs.postPatch or "")
    + ''
      substituteInPlace src/classes/window/presenter.vala \
        --replace-fail 'height -= jutting;' 'height = int.max(height - jutting, 1);'
    ''
    # Slides are rendered at the scale of the monitor pdfpc was told to use, captured once at window
    # construction. A window shown on any other display then renders at the wrong resolution, and on a
    # Retina screen a scale-1 buffer is simply stretched. Use the widget's live scale factor instead,
    # which always describes the display the window is actually on.
    + ''
      substituteInPlace src/classes/view/pdf.vala \
        --replace-fail 'width = allocation.width*this.gdk_scale;' \
                       'width = allocation.width*this.get_scale_factor();' \
        --replace-fail 'height = allocation.height*this.gdk_scale;' \
                       'height = allocation.height*this.get_scale_factor();' \
        --replace-fail 'cr.scale((1.0/this.gdk_scale), (1.0/this.gdk_scale));' \
                       'cr.scale((1.0/this.get_scale_factor()), (1.0/this.get_scale_factor()));'
    '';

  # GDK's Quartz backend does not implement fullscreen_on_monitor, so the monitor argument is dropped
  # and the presentation fullscreens over the presenter instead of on the other display. Open both as
  # plain windows to place by hand; an explicit -w still wins, as it comes after this flag.
  preFixup =
    (oldAttrs.preFixup or "")
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      gappsWrapperArgs+=(--add-flags "-w both")
    '';

  meta = oldAttrs.meta // {
    hydraPlatforms = lib.platforms.darwin;
  };
})
