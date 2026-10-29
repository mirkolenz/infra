# Zed settings, imported by ./default.nix.
# The leading underscore hides this data file from import-tree.
# https://zed.dev/docs/configuring-zed
{
  config,
  lib,
  llamaCpp,
}:
let
  bin = name: "${config.home.profileDirectory}/bin/${name}";
  llamaCppUrl = "http://${llamaCpp.settings.host}:${toString llamaCpp.settings.port}";
in
{
  # keep-sorted start block=yes
  agent = {
    threads_sidebar.position = "left";
    default_width = 640;
    default_height = 320;
    flexible = true;
    dock = "left";
    use_modifier_to_send = false;
    play_sound_when_agent_done = "always";
    default_model = {
      effort = "high";
      enable_thinking = true;
      provider = "zed.dev";
      model = "gpt-6.1-sol";
      speed = "standard";
    };
    sandbox_permissions.allow_unsandboxed = false;
  };
  # ls -l "$HOME/Library/Application Support/Zed/extensions/installed/"
  # Extensions of the registered languages and their servers come from options/home-manager/zed.nix.
  auto_install_extensions = lib.genAttrs [
    # keep-sorted start
    "comment"
    "csv"
    "env"
    "flexoki"
    "git-firefly"
    "github-theme"
    "ini"
    "jinja2"
    "log"
    "material-icon-theme"
    "ruby"
    # keep-sorted end
  ] (_: true);
  auto_signature_help = true;
  base_keymap = "Zed";
  buffer_font_family = config.custom.font.family;
  buffer_font_size = config.custom.font.size;
  code_lens = "on";
  collaboration_panel = {
    dock = "right";
    default_width = 320;
  };
  colorize_brackets = true;
  completions.words = "disabled";
  cursor_blink = false;
  cursor_shape = "bar";
  debugger.dock = "bottom";
  edit_predictions = lib.mergeAttrsList [
    {
      provider = "none";
      disabled_globs = [
        "*.env"
        "*secret*"
      ];
      mode = "eager";
      allow_data_collection = "no";
      copilot.enable_next_edit_suggestions = false;
    }
    (lib.optionalAttrs llamaCpp.enable {
      # `model` must name one of the llama.cpp presets.
      open_ai_compatible_api = {
        api_url = "${llamaCppUrl}/v1";
        max_output_tokens = 16;
        model = "qwen3.8-27b";
      };
    })
  ];
  excerpt_context_lines = 5;
  expand_excerpt_lines = 5;
  extend_comment_on_newline = false;
  file_types = {
    Jinja2 = [
      "j2"
      "jinja2"
      "jinja"
    ];
    "Plain Text" = [ "jjdescription" ];
  };
  format_on_save = "on";
  git = {
    inline_blame.enabled = false;
    blame.show_avatar = true;
  };
  git_panel = {
    dock = "right";
    tree_view = true;
    default_width = 320;
  };
  icon_theme = {
    mode = "system";
    light = "Zed (Default)";
    dark = "Material Icon Theme";
  };
  inlay_hints = {
    enabled = true;
    show_background = true;
    edit_debounce_ms = 300;
  };
  language_models = lib.optionalAttrs llamaCpp.enable {
    "llama.cpp".api_url = llamaCppUrl;
  };
  # The language servers and formatters come from options/home-manager.
  languages = {
    # keep-sorted start block=yes
    "Plain Text".soft_wrap = "editor_width";
    BibTeX.soft_wrap = "editor_width";
    LaTeX.soft_wrap = "editor_width";
    MDX.soft_wrap = "editor_width";
    Markdown.soft_wrap = "editor_width";
    Python.tab_size = 4;
    Typst.soft_wrap = "editor_width";
    # keep-sorted end
  };
  line_ending = "prefer_lf";
  node = {
    path = bin "node";
    npm_path = bin "npm";
  };
  outline_panel = {
    dock = "right";
    default_width = 320;
  };
  preferred_line_length = 120;
  project_panel = {
    dock = "right";
    default_width = 320;
    entry_spacing = "standard";
    indent_size = 16;
    scrollbar.show = "system";
  };
  relative_line_numbers = "disabled";
  scrollbar.show = "always";
  # On top of tree-sitter, like the other editors.
  semantic_tokens = "combined";
  session.trust_all_worktrees = true;
  sticky_scroll.enabled = false;
  tab_size = 2;
  tabs = {
    file_icons = true;
    git_status = true;
    show_diagnostics = "all";
  };
  terminal = {
    detect_venv = "off";
    line_height = "standard";
    scrollbar.show = "system";
    option_as_meta = true;
    dock = "bottom";
    default_width = 640;
    default_height = 320;
  };
  theme = {
    mode = "system";
    light = "Gruvbox Light Hard";
    dark = "Gruvbox Dark Hard";
  };
  toolbar = {
    agent_review = false;
    breadcrumbs = false;
    code_actions = false;
    quick_actions = false;
    selections_menu = false;
  };
  # ui_font_family = config.custom.font.family;
  ui_font_size = 15;
  use_smartcase_search = true;
  use_system_path_prompts = false;
  use_system_prompts = false;
  vim = {
    use_system_clipboard = "on_yank";
    toggle_relative_line_numbers = true;
    use_smartcase_find = true;
  };
  vim_mode = false;
  # keep-sorted end
}
