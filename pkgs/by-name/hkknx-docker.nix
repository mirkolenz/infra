{
  lib,
  cacert,
  tzdata,
  dockerTools,
  hkknx-bin,
}:
dockerTools.streamLayeredImage {
  name = "hkknx";
  tag = "latest";
  created = "now";
  contents = [
    cacert
    tzdata
    hkknx-bin
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
