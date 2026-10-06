{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      uv = lib.getExe config.programs.uv.package;
    in
    {
      programs.uv = {
        enable = true;
        package = pkgs.uv-bin;
        # https://docs.astral.sh/uv/reference/settings/
        settings = {
          exclude-newer = "3 days";
          python-downloads = "manual";
          python-preference = "system";
        };
      };
      home.shellAliases.py = "${uv} run";
      custom.bump.uv = {
        files = [
          "pyproject.toml"
          "uv.lock"
        ];
        text = ''
          ${lib.getExe pkgs.uv-upgrade}
          ${uv} sync --upgrade --all-extras --all-groups
        '';
      };
      home.activation = {
        pruneUvCache = lib.hm.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
          run ${uv} cache prune --force $VERBOSE_ARG
        '';
      };
    };
}
