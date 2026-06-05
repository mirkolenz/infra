{
  flake.modules.homeManager.default =
    { pkgs, ... }:
    {
      programs.ruff = {
        enable = true;
        package = pkgs.ruff-bin;
        # https://docs.astral.sh/ruff/settings/
        settings = {
          fix = true;
          output-format = "concise";
          unsafe-fixes = true;
        };
      };
    };
}
