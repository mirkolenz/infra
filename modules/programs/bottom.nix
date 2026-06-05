{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.bottom = {
        enable = true;
        settings = {
          # https://github.com/ClementTsang/bottom/blob/master/sample_configs/default_config.toml
          flags = {
            # Whether to hide the average cpu entry.
            #hide_avg_cpu = false
            # Whether to use dot markers rather than braille.
            #dot_marker = false
            # The update rate of the application.
            rate = 1000;
            # Whether to put the CPU legend to the left.
            #left_legend = false
            # Whether to set CPU% on a process to be based on the total CPU or just current usage.
            #current_usage = false
            # Whether to set CPU% on a process to be based on the total CPU or per-core CPU% (not divided by the number of cpus).
            #unnormalized_cpu = false
            # Whether to group processes with the same name together by default.
            #group_processes = false
            # Whether to make process searching case sensitive by default.
            #case_sensitive = false
            # Whether to make process searching look for matching the entire word by default.
            #whole_word = false
            # Whether to make process searching use regex by default.
            #regex = false
            # Defaults to Celsius.  Temperature is one of:
            #temperature_type = "k"
            #temperature_type = "f"
            temperature_type = "c";
            #temperature_type = "kelvin"
            #temperature_type = "fahrenheit"
            #temperature_type = "celsius"
            # The default time interval (in milliseconds).
            #default_time_value = 60000
            # The time delta on each zoom in/out action (in milliseconds).
            #time_delta = 15000
            # Hides the time scale.
            #hide_time = false
            # Override layout default widget
            #default_widget_type = "proc"
            #default_widget_count = 1
            # Expand selected widget upon starting the app
            #expanded_on_startup = true
            # Use basic mode
            #basic = false
            # Use the old network legend style
            #use_old_network_legend = false
            # Remove space in tables
            #hide_table_gap = false
            # Show the battery widgets
            #battery = false
            # Disable mouse clicks
            #disable_click = false
            # Built-in themes.  Valid values are "default", "default-light", "gruvbox", "gruvbox-light", "nord", "nord-light"
            #color = "default"
            # Show memory values in the processes widget as values by default
            #mem_as_value = false
            # Show tree mode by default in the processes widget.
            #tree = false
            # Shows an indicator in table widgets tracking where in the list you are.
            #show_table_scroll_position = false
            # Show processes as their commands by default in the process widget.
            #process_command = false
            # Displays the network widget with binary prefixes.
            #network_use_binary_prefix = false
            # Displays the network widget using bytes.
            #network_use_bytes = false
            # Displays the network widget with a log scale.
            #network_use_log = false
            # Hides advanced options to stop a process on Unix-like systems.
            #disable_advanced_kill = false
            # Shows GPU(s) memory
            enable_gpu_memory = true;
            # Shows cache and buffer memory
            #enable_cache_memory = false
            # How much data is stored at once in terms of time.
            # retention = "10m"
          };

          processes = {
            columns = [
              "pid"
              "name"
              "cpu%"
              "mem%"
              "read"
              "write"
              "user"
            ];
          };
        };
      };
    };
}
