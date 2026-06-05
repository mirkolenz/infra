{
  flake.modules.nixvim.default = {
    plugins.snacks.settings.dashboard = {
      enabled = true;
      preset.keys = [
        {
          icon = " ";
          key = "f";
          desc = "Find File";
          action = ":lua Snacks.dashboard.pick('files')";
        }
        {
          icon = " ";
          key = "n";
          desc = "New File";
          action = ":ene | startinsert";
        }
        {
          icon = " ";
          key = "g";
          desc = "Find Text";
          action = ":lua Snacks.dashboard.pick('live_grep')";
        }
        {
          icon = " ";
          key = "r";
          desc = "Recent Files";
          action = ":lua Snacks.dashboard.pick('oldfiles')";
        }
        {
          icon = " ";
          key = "p";
          desc = "Recent Projects";
          action = ":lua Snacks.dashboard.pick('projects')";
        }
        {
          icon = " ";
          key = "q";
          desc = "Quit";
          action = ":qa";
        }
      ];
      sections = [
        { section = "header"; }
        {
          # icon = " ";
          # title = "Keymaps";
          section = "keys";
          padding = 1;
          # indent = 2;
        }
        {
          # icon = " ";
          # title = "Projects";
          section = "projects";
          padding = 1;
          # indent = 2;
          limit = 9;
        }
      ];
    };
  };
}
