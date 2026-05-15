{ ... }:
{
  plugins.lualine = {
    settings = {
      options = {
        icons_enabled = true;
        globalstatus = true;
        section_separators = {
          left = "";
          right = "";
        };
        component_separators = {
          left = "│";
          right = "│";
        };
      };
      sections = {
        lualine_a = [ "mode" ];
        lualine_b = [
          "branch"
          "diff"
          "diagnostics"
        ];
        lualine_c = [ "filename" ];
        lualine_x = [
          "encoding"
          "fileformat"
          "filetype"
        ];
        lualine_y = [ "progress" ];
        lualine_z = [ "location" ];
      };
      inactive_sections = {
        lualine_a = [ ];
        lualine_b = [ ];
        lualine_c = [ "filename" ];
        lualine_x = [ "location" ];
        lualine_y = [ ];
        lualine_z = [ ];
      };
      tabline = {
        lualine_a = [
          {
            __unkeyed = "tabs";
            mode = 2;
            show_modified_status = true;
            symbols.modified = " ●";
            tabs_color = {
              active = "lualine_a_normal";
              inactive = "lualine_a_inactive";
            };
          }
        ];
        lualine_b = [
          {
            __unkeyed = "buffers";
            mode = 2;
            icons_enabled = true;
            show_filename_only = true;
            show_modified_status = true;
            use_mode_colors = false;
            symbols = {
              modified = " ●";
              alternate_file = "";
              directory = "";
            };
            buffers_color = {
              active = "lualine_b_normal";
              inactive = "lualine_c_inactive";
            };
            max_length = 200;
          }
        ];
        lualine_c = [ ];
        lualine_x = [ ];
        lualine_y = [ ];
        lualine_z = [ ];
      };
      winbar = {
        lualine_a = [ ];
        lualine_b = [ ];
        lualine_c = [ ];
        lualine_x = [ ];
        lualine_y = [ ];
        lualine_z = [ ];
      };
      inactive_winbar = {
        lualine_a = [ ];
        lualine_b = [ ];
        lualine_c = [ ];
        lualine_x = [ ];
        lualine_y = [ ];
        lualine_z = [ ];
      };
    };
  };
}
