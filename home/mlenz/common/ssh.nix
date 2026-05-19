{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.custom.features.withDisplay {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = lib.mkIf pkgs.stdenv.isDarwin [
      "${config.home.homeDirectory}/.orbstack/ssh/config"
    ];
    settings = {
      "*" = {
        # default config from home manager module
        ForwardAgent = false;
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
      };
      "gpu" = {
        HostName = "gpu.wi2.uni-trier.de";
        ForwardAgent = true;
        User = "lenz";
      };
      "kitei" = {
        HostName = "kitei-gpu.wi2.uni-trier.de";
        User = "compute";
      };
      "raise" = {
        HostName = "raise.dfki.de";
        ForwardAgent = true;
        User = "mlenz";
      };
      "macpro homeserver" = {
        HostName = "macpro.taildc4a8b.ts.net";
        ForwardAgent = true;
        User = "mlenz";
      };
      "raspi" = {
        HostName = "raspi.taildc4a8b.ts.net";
        ForwardAgent = true;
        User = "mlenz";
      };
    };
  };
}
