# CUPS on graphical hosts, with Avahi so the print dialogs discover driverless
# IPP Everywhere / AirPrint printers on the LAN. Printers are configured through
# the desktop settings panel, so the daemon is reachable only over its local
# unix socket.
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      services.printing = {
        enable = true;
        # the admin web UI carries most of the historical CUPS CVEs and the
        # settings panel does not need it
        webInterface = false;
        # drop the localhost:631 TCP listener; cupsd always keeps
        # /run/cups/cups.sock, which is what libcups falls back to. This also
        # puts the daemon out of reach of a browser tab (CSRF/DNS rebinding).
        listenAddresses = [ ];
      };

      services.avahi = {
        enable = true;
        # resolve .local hostnames, which driverless printers advertise themselves under
        nssmdns4 = true;
        # UDP 5353, needed for the printers to answer our mDNS queries
        openFirewall = true;
      };

      # Two responders on UDP 5353 make mDNS unreliable, so Avahi owns it alone.
      services.resolved.settings.Resolve.MulticastDNS = false;
    };
}
