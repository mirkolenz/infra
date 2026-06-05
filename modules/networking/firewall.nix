# macOS application firewall.
{
  flake.modules.darwin.default = {
    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
      allowSigned = true;
      allowSignedApp = true;
      blockAllIncoming = false;
    };
  };
}
