{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (config.programs.herdr) plugins;
      inherit (config.custom) projectsPath;

      # Repositories are checked out as <owner>/<repo>, putting `.git` three levels below the root.
      # `worktree open` focuses the repository's workspace when one exists and otherwise creates a
      # worktree-backed one, which is what the `open_worktree` binding operates on.
      projectPicker = pkgs.writeShellApplication {
        name = "herdr-project-picker";
        runtimeInputs = [
          config.programs.herdr.package
          pkgs.fd
          pkgs.fzf
        ];
        text = ''
          repo=$(
            fd --hidden --no-ignore --type d --max-depth 3 --glob .git \
              --base-directory "${projectsPath}" --format '{//}' \
              | fzf --prompt 'project> '
          ) || exit 0

          herdr worktree open --cwd "${projectsPath}/$repo" --path "${projectsPath}/$repo" --focus
        '';
      };
    in
    {
      programs.fish.interactiveShellInit = ''
        source ${plugins.automatic-rename.package.root}/shell/hook.fish
      '';

      # The shell hooks are sourced by fish rather than spawned by herdr, so they never see
      # `$HERDR_PLUGIN_CONFIG_DIR` and the plugin reads this fixed path instead.
      # https://github.com/qu8n/herdr-automatic-rename/blob/main/config.example.sh
      xdg.configFile."herdr-automatic-rename/config.sh".text = ''
        AUTO_INDEX=0
        SHOW_PROGRAM_ARGS=0
        AGENT_TITLES=0
        ICONS_ENABLED=1
        ICON_FALLBACK='󰆍'
        ICON_MAP=(
          "fresh=󰏫"
        )
      '';

      programs.herdr = {
        enable = true;
        package = pkgs.herdr-bin;

        plugins = {
          automatic-rename.enable = true;
          file-viewer.enable = true;
          plus.enable = true;
          reviewr = {
            enable = true;
            # The pane is bound to `prefix+ctrl+r` below, so it does not need to claim a
            # split of every worktree workspace as it is created.
            # https://github.com/persiyanov/herdr-reviewr#configuration
            settings.auto_open = false;
          };
        };

        # https://herdr.dev/docs/configuration/
        settings = {
          onboarding = false;
          theme.name = "gruvbox";
          update.version_check = false;
          terminal = {
            default_shell = "fish";
            new_cwd = "follow";
          };
          keys = {
            prefix = "ctrl+space";
            # tmux-style jump back to the previously focused pane (across tabs/workspaces).
            last_pane = "prefix+;";
            # Built-in worktree picker, scoped to the focused workspace's repository rather
            # than to every project root the way the sessionizer action was.
            open_worktree = "prefix+ctrl+w";
            command = [
              {
                key = "prefix+ctrl+r";
                type = "plugin_action";
                command = "${plugins.reviewr.name}.toggle";
                description = "review the agent's diff";
              }
              {
                key = "prefix+ctrl+p";
                type = "popup";
                command = lib.getExe projectPicker;
                description = "open a project workspace";
                width = "60%";
                height = "60%";
              }
            ];
          };
          ui = {
            copy_on_select = false;
            right_click_passthrough_modifier = "ctrl";
            toast = {
              delivery = "terminal";
              delay_seconds = 0;
              herdr.position = "bottom-right";
              clipboard.position = "bottom-right";
            };
            sound.enabled = false;
            prompt_new_tab_name = false;
            prompt_new_workspace_name = false;
            window_title = "herdr: {workspace}";
          };
          session = {
            resume_agents_on_restore = false;
          };
          experimental = {
            kitty_graphics = true;
          };
        };
      };
    };
}
