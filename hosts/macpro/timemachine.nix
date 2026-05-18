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
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      workstation = true;
      userServices = true;
    };
    # vfs_fruit does not announce the share over mDNS; Avahi must do it
    # so macOS lists the host in Finder and Time Machine recognises it.
    # https://wiki.nixos.org/wiki/Samba#Time_Machine
    extraServiceFiles.timemachine = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
        <service>
          <type>_device-info._tcp</type>
          <port>0</port>
          <txt-record>model=MacPro</txt-record>
        </service>
        <service>
          <type>_adisk._tcp</type>
          <txt-record>dk0=adVN=timemachine,adVF=0x82</txt-record>
          <txt-record>sys=waMa=0,adVF=0x100</txt-record>
        </service>
      </service-group>
    '';
  };
}
