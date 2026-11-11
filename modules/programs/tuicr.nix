{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    lib.mkIf config.custom.features.extras.enable {
      programs.tuicr = {
        enable = true;
        # https://github.com/agavra/tuicr/blob/main/docs/CONFIG.md
        settings = {
          theme = "gruvbox-dark";
          wrap = true;
          no_update_check = true;
          username = config.custom.user.name;
          # follows the working tree as agents change it, like hunk
          diff_watch_interval_ms = 1000;
          # the types and their meaning that the upstream agent skill handles,
          # the first one is the default
          comment_types = [
            {
              id = "issue";
              color = "red";
              definition = "blocking problem to fix first";
            }
            {
              id = "suggestion";
              color = "blue";
              definition = "consider implementing or explain why not";
            }
            {
              id = "note";
              color = "yellow";
              definition = "answer or acknowledge";
            }
            {
              id = "praise";
              color = "cyan";
              definition = "no action required";
            }
          ];
        };
      };
    };
}
