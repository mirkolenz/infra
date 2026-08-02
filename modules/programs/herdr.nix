{
  flake.modules.homeManager.default =
    {
      pkgs,
      config,
      ...
    }:
    let
      # Open a new focused herdr tab and run the given command in it, labelling
      # the tab after the command's program name. (herdr has no single-command
      # equivalent, so we create the tab and run in its root pane in two steps.)
      htab = pkgs.writeShellApplication {
        name = "htab";
        runtimeInputs = [
          config.programs.herdr.package
          pkgs.jq
        ];
        text = ''
          pane_id="$(herdr tab create --label "$1" --focus | jq -r '.result.root_pane.pane_id')"
          exec herdr pane run "$pane_id" "$*"
        '';
      };

      inherit (pkgs) herdrPlugins;

      plugins = with herdrPlugins; [
        file-viewer
        plus
        reviewr
      ];

      # Same tabs as the zellij `ide` layout. herdr-plus lays this into every
      # worktree workspace, since `repo = "*"` matches any repository.
      defaultLayout = {
        repo = "*";
        tabs = [
          {
            name = "edit";
            command = "nvim";
          }
          {
            name = "files";
            command = "yazi";
          }
          {
            name = "git";
            command = "lazygit";
          }
          { name = "shell"; }
        ];
      };
    in
    {
      home.packages = [ htab ];

      # herdr replaces every cached field from the manifest when it reads this
      # registry, so only the paths and the enabled flag matter here. Installing
      # or toggling a plugin through herdr rewrites the file over the symlink,
      # which `force` then takes back on the next activation.
      xdg.configFile."herdr/plugins.json" = {
        force = true;
        source = (pkgs.formats.json { }).generate "herdr-plugins.json" (
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

      # herdr points the plugin at this managed config dir, which takes precedence
      # over the ~/.config/herdr-plus the binary falls back to outside herdr.
      xdg.configFile."herdr/plugins/config/${herdrPlugins.plus.pluginId}/worktrees/default.toml".source =
        (pkgs.formats.toml { }).generate "herdr-plus-default-layout.toml"
          defaultLayout;

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
            # Reuse the htab command via a background shell to open the command in a new tab.
            command = [
              {
                key = "prefix+alt+g";
                type = "shell";
                command = "htab lazygit";
                description = "lazygit in a new tab";
              }
              {
                key = "prefix+alt+e";
                type = "shell";
                command = "htab nvim";
                description = "nvim in a new tab";
              }
              {
                key = "prefix+alt+y";
                type = "shell";
                command = "htab yabai";
                description = "yabai in a new tab";
              }
              {
                key = "prefix+alt+f";
                type = "plugin_action";
                command = "${herdrPlugins.file-viewer.pluginId}.open-file-viewer";
                description = "file viewer beside the current pane";
              }
              {
                key = "prefix+alt+r";
                type = "plugin_action";
                command = "${herdrPlugins.reviewr.pluginId}.toggle";
                description = "review the agent's diff";
              }
              {
                key = "prefix+alt+p";
                type = "plugin_action";
                command = "${herdrPlugins.plus.pluginId}.projects";
                description = "open a project workspace";
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
            prompt_new_tab_name = true;
            prompt_new_workspace_name = true;
          };
          session = {
            resume_agents_on_restore = false;
          };
        };
      };
    };
}
