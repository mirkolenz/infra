{
  lib,
  dockerTools,
  hkknx-bin,
  pkgsStatic,
}:
dockerTools.streamLayeredImage {
  name = "hkknx";
  # hkknx embeds Go's time/tzdata, so the image needs no zoneinfo.
  contents = [
    dockerTools.caCertificates
    hkknx-bin
    # sh and wget for healthchecks, static to keep glibc out of the closure.
    pkgsStatic.busybox
  ];
  # create /tmp for backup feature to work
  extraCommands = ''
    mkdir -m 1777 tmp
  '';
  config = {
    Entrypoint = [
      (lib.getExe hkknx-bin)
      "--autoupdate"
      "false"
      "--db"
      "/db"
      "--port"
      "80"
    ];
    ExposedPorts = {
      "80/tcp" = { };
      "3671/udp" = { };
      "5353/udp" = { };
    };
  };
  meta = {
    description = "Container image serving the HomeKit Bridge for KNX";
    homepage = "https://hub.docker.com/r/brutella/hkknx";
    inherit (hkknx-bin.meta) license;
    maintainers = with lib.maintainers; [ mirkolenz ];
    platforms = lib.platforms.linux;
  };
}
