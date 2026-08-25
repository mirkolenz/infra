{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      ...
    }:
    let
      inherit (pkgs) herdrPlugins;

      plugins = with herdrPlugins; [
        automatic-rename
        file-viewer
        plus
        reviewr
        sessionizer
      ];
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

      # Sessionizer discovers repositories below each owner directory.
      # This fallback provides a consistent project workspace.
      # A repository can replace it with its own .sessionizer/config.toml.
      xdg.configFile."herdr/plugins/config/${herdrPlugins.sessionizer.pluginId}/config.toml".source =
        pkgs.writers.writeTOML "herdr-sessionizer.toml"
          {
            projects = {
              roots = [ "${config.home.homeDirectory}/Developer/*" ];
              git_only = true;
              depth = 1;
            };
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
            prefix = "ctrl+b";
            # tmux-style jump back to the previously focused pane (across tabs/workspaces).
            last_pane = "prefix+;";
            command = [
              {
                key = "prefix+ctrl+r";
                type = "plugin_action";
                command = "${herdrPlugins.reviewr.pluginId}.toggle";
                description = "review the agent's diff";
              }
              {
                key = "prefix+ctrl+p";
                type = "plugin_action";
                command = "${herdrPlugins.sessionizer.pluginId}.open";
                description = "open a project workspace";
              }
              {
                key = "prefix+ctrl+w";
                type = "plugin_action";
                command = "${herdrPlugins.sessionizer.pluginId}.worktree-open";
                description = "open a worktree workspace";
              }
            ];
          };
          ui = {
            toast = {
              delivery = "terminal";
              herdr.position = "bottom-right";
              clipboard.position = "bottom-right";
            };
            sound.enabled = false;
            show_agent_labels_on_pane_borders = true;
            prompt_new_tab_name = false;
            prompt_new_workspace_name = true;
          };
          session = {
            resume_agents_on_restore = false;
          };
        };
      };
    };
}
