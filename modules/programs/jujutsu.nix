{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    {
      # jj keeps the config of every repository here instead of within it, out of reach of agents
      programs.agents.sandbox.paths.read = [ "${config.xdg.configHome}/jj" ];
      programs.jujutsu = {
        enable = true;
        # https://docs.jj-vcs.dev/latest/config/
        settings = {
          # keep-sorted start block=yes
          aliases = {
            # keep-sorted start block=yes
            c = [
              "commit"
            ];
            ci = [
              "commit"
              "--interactive"
            ];
            clone = [
              "git"
              "clone"
            ];
            d = [
              "describe"
            ];
            e = [
              "edit"
            ];
            f = [
              "git"
              "fetch"
            ];
            fetch = [
              "git"
              "fetch"
            ];
            init = [
              "git"
              "init"
            ];
            n = [
              "new"
            ];
            nb = [
              "bookmark"
              "create"
              "--revision"
              "@-"
            ];
            p = [
              "git"
              "push"
            ];
            pull = [
              "git"
              "fetch"
            ];
            push = [
              "git"
              "push"
            ];
            r = [
              "rebase"
            ];
            remote = [
              "git"
              "remote"
            ];
            s = [
              "squash"
            ];
            si = [
              "squash"
              "--interactive"
            ];
            tug = [
              "bookmark"
              "advance"
            ];
            # keep-sorted end
          };
          # https://github.com/jj-vcs/jj/discussions/3549
          experimental-advance-branches = {
            enabled-branches = [
              "*"
            ];
            disabled-branches = [
              "main"
              "push-*"
            ];
          };
          remotes.origin.auto-track-created-bookmarks = "*";
          revsets.bookmark-advance-to = "heads(::@ ~ empty())";
          ui = {
            merge-editor = lib.mkIf config.programs.mergiraf.enable "mergiraf";
            # editor = "micro";
          };
          user = {
            name = config.custom.user.name;
            email = config.custom.user.mail;
          };
          # keep-sorted end
        };
      };
      programs.jjui = {
        enable = lib.mkDefault config.custom.features.extras.enable;
      };
    };
}
