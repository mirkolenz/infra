{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (pkgs) herdrPlugins;
      inherit (config.custom) projectsPath;

      plugins = with herdrPlugins; [
        automatic-rename
        file-viewer
        plus
        reviewr
      ];

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
        source ${herdrPlugins.automatic-rename.root}/shell/hook.fish
      '';

      # herdr replaces every cached field from the manifest when it reads this
      # registry, so only the paths and the enabled flag matter here. Installing
      # or toggling a plugin through herdr rewrites the file over the symlink,
      # which `force` then takes back on the next activation.
      xdg.configFile."herdr/plugins.json" = {
        force = true;
        source = pkgs.writers.writeJSON "herdr-plugins.json" (
          map (plugin: {
            plugin_id = plugin.pluginId;
            name = plugin.pname;
            inherit (plugin) version;
            plugin_root = plugin.root;
            manifest_path = plugin.manifest;
            enabled = true;
          }) plugins
        );
      };

      # https://github.com/persiyanov/herdr-reviewr#configuration
      # The pane is bound to `prefix+ctrl+r` below, so it does not need to claim a
      # split of every worktree workspace as it is created.
      xdg.configFile."herdr/plugins/config/${herdrPlugins.reviewr.pluginId}/config.toml".source =
        (pkgs.formats.toml { }).generate "herdr-reviewr.toml" {
          auto_open = false;
        };

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
                command = "${herdrPlugins.reviewr.pluginId}.toggle";
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
