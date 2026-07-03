{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      # https://ampcode.com/manual#configuration
      programs.amp-cli = {
        enable = false;
        settings.amp = {
          git.commit = {
            ampThread.enabled = true;
            coauthor.enabled = false;
          };
          updates.mode = "disabled";
        };
      };
    };
}
