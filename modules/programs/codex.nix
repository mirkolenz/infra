{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      agents = config.programs.agents;
      inherit (agents) sandbox;
      cfg = config.programs.codex;

      prefixRule = decision: cmd: ''
        prefix_rule(pattern = ${lib.toJSON (lib.splitString " " cmd)}, decision = "${decision}")
      '';
    in
    lib.mkIf config.programs.agents.enable {
      programs.codex = {
        enable = true;
        package = pkgs.codex-bin;
        enableMcpIntegration = true;
        inherit (agents) context skills;
        defaultLauncher = false;
        installations = {
          personal = { };
          work = { };
        };
        # https://developers.openai.com/codex/rules
        rules.commands = lib.concatStrings (
          map (prefixRule "allow") sandbox.commands.allow
          ++ map (prefixRule "forbidden") sandbox.commands.deny
        );
        # https://developers.openai.com/codex/config-reference
        # https://developers.openai.com/codex/config-schema.json
        settings = {
          model = "gpt-6.1-sol";
          model_reasoning_effort = "high";
          model_verbosity = "low";
          agents = {
            default_subagent_model = "gpt-6.1-terra";
            default_subagent_reasoning_effort = "medium";
          };
          # counterpart to Claude's `allowUnsandboxedCommands = false`
          approval_policy.granular = {
            sandbox_approval = false;
            mcp_elicitations = true;
            rules = true;
            request_permissions = true;
            skill_approval = true;
          };
          approvals_reviewer = "auto_review";
          file_opener = "none";
          check_for_update_on_startup = false;
          web_search = "live";
          service_tier = "default";
          forced_login_method = "chatgpt";
          memories = {
            generate_memories = false;
            use_memories = false;
          };
          # https://developers.openai.com/codex/permissions
          default_permissions = "workspace-net";
          permissions.workspace-net = {
            # :workspace grants writable workspace roots, read-only .git/.codex within
            # them, :minimal read access, and write to :tmpdir and :slash_tmp (/tmp).
            extends = ":workspace";
            filesystem = {
              ":workspace_roots" = {
                ".git" = "write";
              };
            }
            // lib.genAttrs sandbox.paths.read (_: "read")
            // lib.genAttrs sandbox.paths.write (_: "write")
            # deny wins over the read granted by :workspace, keeping ssh keys unreadable
            // lib.genAttrs sandbox.paths.deny (_: "deny");
            network = {
              enabled = true;
              # also the connections to localhost and private networks
              allow_local_binding = sandbox.localhost;
              # Codex has no counterpart to claude's `strictAllowlist`: the one switch that
              # would let it ask for a host beyond this list is `sandbox_approval`, which
              # also reopens `require_escalated`, so the list stays the whole boundary.
              domains =
                lib.genAttrs sandbox.domains.allow (_: "allow") // lib.genAttrs sandbox.domains.deny (_: "deny");
              unix_sockets = lib.genAttrs sandbox.unixSockets (_: "allow");
            };
          };
          # the domain rules above need it to apply
          features.network_proxy = true;
          tui = {
            notifications = true;
            vim_mode_default = false;
            # scrolling within codex deadlocks its pty with nono
            alternate_screen = "never";
            copy_on_select = "always";
            show_tooltips = false;
            auto_recap = false;
          };
          notice = {
            hide_rate_limit_model_nudge = true;
          };
          shell_environment_policy = {
            filters = lib.genAttrs sandbox.environment.unset (_: "exclude");
            inherit (sandbox.environment) set;
          };
          desktop = {
            followUpQueueMode = "queue";
            show-context-window-usage = true;
            hotkey-window-projectless-default-enabled = true;
            appearanceDarkCodeThemeId = "codex";
            appearanceLightCodeThemeId = "codex";
            usePointerCursors = false;
            git-pull-request-merge-method = "squash";
            mac-menu-bar-enabled = false;
            open-in-target-preferences.global = "zed";
            composerPlainTextMode = true;
            enabled-reasoning-efforts = [
              "low"
              "medium"
              "high"
              "xhigh"
              "ultra"
              "max"
            ];
          };
        };
      };
      programs.agents = {
        # the login is kept in `auth.json`
        harnesses.codex = {
          inherit (cfg) launchers;
          addDirFlag = "--add-dir";
          # nono takes over, and a running daemon would serve the session outside of it.
          # nono keeps config.toml read-only, so the profile receives trust and other writes,
          # layered on top and only loaded within nono.
          sandboxArgs = [
            "--no-daemon"
            "--profile"
            "nono"
            "-c"
            ''default_permissions=":danger-full-access"''
          ];
          domains = [
            "auth.openai.com"
            "chatgpt.com"
          ];
          # the browser use of the ChatGPT app, whose in-app browser serves it here
          unixSocketDirs = [ "/tmp/codex-browser-use" ];
          paths.write = cfg.configDirs;
          # the managed config, the hooks and the app-server daemon of every installation
          paths.read = cfg.protectedPaths;
        };
        # The project config, except for the skills.
        # Codex protects `.agents` natively, except for the skills of every agent there.
        sandbox.workspace.read = [ ".codex" ];
        sandbox.workspace.write = [
          ".agents/skills"
          ".codex/skills"
        ];
      };
    };
}
