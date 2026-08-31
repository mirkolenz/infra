{
  flake.modules.homeManager.default =
    { pkgs, lib, ... }:
    let
      pythonRootMarkers = [
        "pyproject.toml"
        ".git"
      ];

      # tsgo handles the language features, oxlint adds lint diagnostics and
      # quick fixes. Formatting goes through the oxfmt formatter below.
      webServers = [
        {
          command = "tsgo";
          args = [
            "--lsp"
            "--stdio"
          ];
          auto_start = true;
          root_markers = [
            "tsconfig.json"
            "jsconfig.json"
            "package.json"
            ".git"
          ];
        }
        {
          command = "oxlint";
          args = [ "--lsp" ];
          auto_start = true;
          only_features = [
            "diagnostics"
            "code_action"
          ];
          initialization_options.settings = {
            run = "onType";
            typeAware = true;
          };
        }
      ];

      # Every language oxfmt can parse, replacing the prettier defaults.
      oxfmtLanguages = [
        "css"
        "html"
        "javascript"
        "json"
        "jsonc"
        "markdown"
        "typescript"
        "yaml"
      ];
    in
    {
      programs.fresh-editor = {
        enable = true;
        package = pkgs.fresh-editor-bin;
        settings = {
          theme = "builtin://dark";
          check_for_updates = false;
          keybindings = [
            {
              key = "o";
              modifiers = [ "ctrl" ];
              action = "quick_open_files";
              when = "global";
            }
            {
              key = "a";
              modifiers = [ "ctrl" ];
              action = "select_all";
              when = "normal";
            }
          ];
          file_browser = {
            show_hidden = true;
          };
          file_explorer = {
            show_hidden = true;
            show_gitignored = true;
          };
          editor = {
            completion_popup_auto_show = true;
            enable_semantic_tokens_full = true;
            ensure_final_newline_on_save = true;
            indentation_guide = "all";
            nerd_font_icons = true;
            trim_trailing_whitespace_on_save = true;
          };
          plugins = {
            git_explorer.settings.colorNames = true;
          };
          # https://getfresh.dev/docs/features/lsp
          # An attribute set patches the built-in server of a language, so only
          # a language served by several servers needs a list. Server settings
          # are answered from initialization_options, using the section each
          # server requests.
          lsp = {
            # keep-sorted start block=yes
            astro.auto_start = true;
            bash.auto_start = true;
            css.auto_start = true;
            dockerfile = {
              command = "docker-language-server";
              args = [
                "start"
                "--stdio"
              ];
              auto_start = true;
            };
            go.auto_start = true;
            html.auto_start = true;
            java.auto_start = true;
            javascript = webServers;
            json.auto_start = true;
            jsonc.auto_start = true;
            latex = {
              auto_start = true;
              initialization_options.texlab = {
                bibtexFormatter = "tex-fmt";
                latexFormatter = "tex-fmt";
                inlayHints = {
                  labelDefinitions = false;
                  labelReferences = false;
                  maxLength = 32;
                };
                build.onSave = false;
              };
            };
            markdown.auto_start = true;
            nix = {
              command = "nixd";
              auto_start = true;
              root_markers = [
                "flake.nix"
                ".git"
              ];
              initialization_options.nixd = {
                formatting.command = [ "nixfmt" ];
                nixpkgs.expr = "import (builtins.getFlake \"pkgs\") { }";
              };
            };
            php.auto_start = true;
            protobuf.auto_start = true;
            python = [
              {
                command = "ruff";
                args = [ "server" ];
                auto_start = true;
                root_markers = pythonRootMarkers;
                only_features = [
                  "diagnostics"
                  "code_action"
                ];
              }
              {
                command = "ty";
                args = [ "server" ];
                auto_start = true;
                root_markers = pythonRootMarkers;
                initialization_options.settings.diagnosticMode = "workspace";
              }
            ];
            toml = {
              command = "tombi";
              args = [ "lsp" ];
              auto_start = true;
            };
            typescript = webServers;
            typst = {
              args = [ "lsp" ];
              auto_start = true;
              initialization_options = {
                exportPdf = "never";
                outputPath = "$root/$name";
              };
            };
            yaml.auto_start = true;
            # keep-sorted end
          };
          # A language without a formatter falls back to its language server,
          # which covers nixd/nixfmt, texlab/tex-fmt, gopls, tombi, buf and the
          # prettier bundled with astro-ls.
          languages =
            lib.genAttrs oxfmtLanguages (_: {
              format_on_save = true;
              formatter = {
                command = "oxfmt";
                args = [
                  "--stdin-filepath"
                  "$FILE"
                ];
                stdin = true;
              };
            })
            // {
              # keep-sorted start block=yes
              astro.format_on_save = true;
              go.format_on_save = true;
              latex.format_on_save = true;
              nix.format_on_save = true;
              php = {
                format_on_save = true;
                formatter = {
                  command = "mago";
                  args = [
                    "format"
                    "--stdin-input"
                  ];
                  stdin = true;
                };
              };
              protobuf.format_on_save = true;
              # The built-in formatter already shells out to ruff.
              python.format_on_save = true;
              toml.format_on_save = true;
              typst = {
                format_on_save = true;
                formatter = {
                  command = "typstyle";
                  stdin = true;
                };
              };
              # keep-sorted end
            };
          # Prose linting for every language, limited to diagnostics and their
          # fixes so it never takes over from the language's own server.
          # https://writewithharper.com/docs/integrations/language-server
          universal_lsp.harper-ls = {
            command = "harper-ls";
            args = [ "--stdio" ];
            auto_start = true;
            only_features = [
              "diagnostics"
              "code_action"
            ];
            initialization_options.harper-ls = {
              diagnosticSeverity = "hint";
              dialect = "American";
              isolateEnglish = true;
              maxFileLength = 1000000;
              # https://writewithharper.com/docs/rules
              linters = {
                LongSentences = false;
                MoreAdjective = false;
                NoFrenchSpaces = false;
                SentenceCapitalization = false;
                Spaces = false;
              };
            };
          };
        };
      };
    };
}
