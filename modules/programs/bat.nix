{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      bat = lib.getExe config.programs.bat.package;
    in
    {
      programs.bat = {
        enable = true;
        config = {
          style = "plain";
          theme = "Monokai Extended";
        };
      };
      home.shellAliases.cat = bat;
      # upstream reports every step of the cache build, which runs on each activation
      # and fails in a directory holding a `cache` entry, https://github.com/sharkdp/bat/issues/1726
      home.activation.batCache = lib.mkForce (
        lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          (cd ${pkgs.emptyDirectory} && XDG_CACHE_HOME=${lib.escapeShellArg config.xdg.cacheHome} run --quiet ${bat} cache --build)
        ''
      );
    };
}
