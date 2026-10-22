{
  configurations.nixos.macpro.module =
    { pkgs, ... }:
    {
      # Samba user management is independent of the system users
      # https://www.samba.org/samba/docs/current/man-html/pdbedit.8.html
      # Add user: sudo pdbedit -a -u USER
      # Change password: sudo pdbedit -u USER
      # Delete user: sudo pdbedit -x USER
      # List users: sudo pdbedit -L
      users = {
        users.timemachine = {
          isSystemUser = true;
          uid = 510;
          group = "timemachine";
        };
        groups.timemachine.gid = 510;
      };
      services.samba = {
        enable = true;
        package = pkgs.samba-tm;
        openFirewall = true;
        settings = {
          global = {
            "server smb encrypt" = "required";
            "server string" = "homeserver";
            "hosts allow" = "10.16.0.0/16 100.64.0.0/10 127.0.0.1 localhost";
            "hosts deny" = "0.0.0.0/0";
            "guest account" = "nobody";
            "map to guest" = "bad user";
            "fruit:aapl" = "yes";
            "fruit:model" = "MacPro";
            "fruit:advertise_fullsync" = "true";
            # smbd registers _smb, _adisk and _device-info with Avahi itself,
            # under the Avahi host name rather than the upper-case NetBIOS name.
            "mdns name" = "mdns";
          };
          timemachine = {
            "path" = "/mnt/backup/timemachine";
            "valid users" = "timemachine";
            "force user" = "timemachine";
            "force group" = "timemachine";
            "public" = "no";
            "browseable" = "yes";
            "writeable" = "yes";
            "fruit:time machine" = "yes";
            "vfs objects" = "catia fruit streams_xattr";
          };
        };
      };
      # for windows network discovery
      services.samba-wsdd = {
        enable = true;
        openFirewall = true;
        discovery = true;
        # pin to LAN interface; listening on all interfaces overflows the netlink socket (ENOBUFS)
        interface = "mv0";
      };
      # for mac network discovery
      services.avahi = {
        enable = true;
        openFirewall = true;
        nssmdns4 = true;
        settings = {
          # pin to LAN interface; advertising on all interfaces makes avahi self-conflict (macpro -> macpro-N)
          server.allow-interfaces = [ "mv0" ];
          publish = {
            disable-publishing = false;
            disable-user-service-publishing = false;
            publish-addresses = true;
            publish-domain = true;
            publish-workstation = true;
          };
        };
      };
    };
}
