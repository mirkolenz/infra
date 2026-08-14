{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.fastfetch = {
        enable = true;
        # https://github.com/fastfetch-cli/fastfetch/wiki/Configuration
        settings = {
          # fastfetch --print-structure
          modules = [
            "title"
            "separator"
            "os"
            "host"
            "kernel"
            "uptime"
            "display"
            "cpu"
            "gpu"
            "memory"
            "swap"
            "disk"
            "localip"
            "battery"
            "poweradapter"
          ];
        };
      };
    };
}
