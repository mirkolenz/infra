{
  lib,
  runCommandLocal,
  makeBinaryWrapper,
  playwright-driver,
  nodejs-slim,
}:
# The headless shell of Playwright, at the revision its CLI expects, confined to localhost.
# Other versions of Playwright look for other revisions, full Chromium does not run within nono.
runCommandLocal "playwright-headless"
  {
    nativeBuildInputs = [ makeBinaryWrapper ];
    meta = {
      description = "Playwright CLI with a headless Chromium confined to localhost for agent sandboxes";
      maintainers = with lib.maintainers; [ mirkolenz ];
      platforms = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      mainProgram = "playwright";
      # only wrappers, but around a closure too large for the binary cache
      hydraPlatforms = [ ];
    };
  }
  ''
    shopt -s failglob
    mkdir -p $out/bin
    cp -rsL --no-preserve=mode ${
      playwright-driver.selectBrowsers {
        withChromium = false;
        withFirefox = false;
        withWebkit = false;
      }
    } $out/browsers

    exe=($out/browsers/*/*/chrome-headless-shell)
    # Its own sandbox cannot nest within that of an agent, and nono keeps `/dev/shm` out of reach on Linux.
    # Everything but loopback goes to a dead proxy, WebRTC included, since nono on Linux opens high ports to every host.
    makeWrapper "$(readlink -f "$exe")" $out/bin/chrome-headless-shell \
      --add-flags "--no-sandbox --disable-dev-shm-usage" \
      --add-flags "--proxy-server=127.0.0.1:9 --force-webrtc-ip-handling-policy=disable_non_proxied_udp"
    ln -sf $out/bin/chrome-headless-shell "$exe"

    makeWrapper ${lib.getExe nodejs-slim} $out/bin/playwright \
      --add-flags ${playwright-driver}/cli.js \
      --set-default PLAYWRIGHT_BROWSERS_PATH $out/browsers
  ''
