{
  flake.modules.homeManager.default =
    { pkgs, ... }:
    {
      programs.ty = {
        enable = true;
        package = pkgs.ty-bin;
        # https://docs.astral.sh/ty/reference/configuration/
        settings = {
          terminal.output-format = "concise";
        };
      };
    };
}
