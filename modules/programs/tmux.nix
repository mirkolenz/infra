{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      programs.tmux = {
        enable = true;
        # https://github.com/tmux-plugins/tmux-sensible
        extraConfig = ''
          set -g display-time 4000
          set -g status-interval 5
          set -g status-keys emacs
          bind C-p previous-window
          bind C-n next-window
          bind a last-window
        '';
        # keep-sorted start
        aggressiveResize = true;
        clock24 = true;
        escapeTime = 0;
        focusEvents = true;
        historyLimit = 50000;
        keyMode = "vi";
        mouse = true;
        newSession = false;
        shell = lib.getExe pkgs.fish;
        shortcut = "a";
        terminal = "screen-256color";
        # keep-sorted end
        plugins = with pkgs.tmuxPlugins; [
          tmux-powerline
        ];
      };
      home.shellAliases = {
        t = lib.getExe config.programs.tmux.package;
      };
    };
}
