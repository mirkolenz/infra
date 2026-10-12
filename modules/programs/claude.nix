{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      lib',
      ...
    }:
    let
      agents = config.programs.agents;
      sandbox = lib'.splitSandbox agents.sandbox;

      withContent = lib'.withContent "**";

      # Absolute paths need the `//` prefix, otherwise a rule is read as relative
      # to the project root.
      mkRules = tool: map (pattern: "${tool}(/${pattern})");

      # a trailing ` *` matches the bare command as well
      bashRules = map (cmd: "Bash(${cmd} *)");

      keychain = {
        path = "$HOME/Library/Keychains";
        when = "macos";
      };

      # https://code.claude.com/docs/en/model-config
      models = {
        fable = "claude-fable-5-1";
        opus = "claude-opus-5-5";
        sonnet = "claude-sonnet-5-5";
        haiku = "claude-haiku-4-5";
      };

      knownMarketplaces = {
        claude-plugins-official = {
          source = "github";
          repo = "anthropics/claude-plugins-official";
        };
        openai-codex = {
          source = "github";
          repo = "openai/codex-plugin-cc";
        };
      };
    in
    lib.mkIf config.programs.agents.enable {
      # https://code.claude.com/docs/en/settings-reference
      programs.claude-code = {
        enable = true;
        package = pkgs.claude-code-bin;
        enableMcpIntegration = true;
        inherit (agents) context skills;
        settings = {
          autoMemoryEnabled = false;
          cleanupPeriodDays = 30;
          effortLevel = "high";
          modelSettings = lib.genAttrs (lib.attrValues models) (_model: {
            effortLevel = "high";
          });
          enableAllProjectMcpServers = true;
          includeGitInstructions = true;
          outputStyle = "Concise";
          skipAutoPermissionPrompt = true;
          spinnerTipsEnabled = false;
          tui = "fullscreen";
          forceLoginMethod = "claudeai";
          attribution = {
            commit = "";
            pr = "";
            sessionUrl = false;
          };
          sandbox = {
            enabled = true;
            # Closes the unsandboxed retry escape hatch. Without this a blocked
            # command can simply be re-run outside the sandbox, which hands the
            # subprocess the real environment again, agent socket included, and
            # every protection below stops applying to it.
            allowUnsandboxedCommands = false;
            enableWeakerNetworkIsolation = true;
            network = {
              allowLocalBinding = sandbox.localhost;
              allowUnixSockets = sandbox.unixSockets;
              # Read access to the macOS network configuration, which codex's network policy
              # already grants. Older reqwest releases read the system proxies through it and
              # panic when the lookup is denied, which breaks hydra-check among others.
              allowMachLookup = [ "com.apple.SystemConfiguration.configd" ];
              # `strictAllowlist` is deliberately unset: it would make this list the whole
              # allowlist and have claude refuse the per-command host lists that auto mode
              # sends through the classifier, turning every unforeseen host into a dead end.
              inherit (sandbox) allowedDomains deniedDomains;
            };
            # `filesystem` is deliberately unset: an `Edit` allow rule grants the sandbox
            # the same write access as `allowWrite`, and a `Read` or `Edit` deny rule the
            # same block as `denyRead`, so the `permissions` block below is the one place
            # the paths are stated and it covers the built-in tools as well.
            credentials = {
              envVars = map (name: {
                inherit name;
                mode = "deny";
              }) sandbox.unset;
            };
          };
          strictKnownMarketplaces = lib.attrValues knownMarketplaces;
          extraKnownMarketplaces = lib.mapAttrs (_name: source: { inherit source; }) knownMarketplaces;
          enabledPlugins = {
            "code-simplifier@claude-plugins-official" = true;
            "feature-dev@claude-plugins-official" = true;
            "frontend-design@claude-plugins-official" = true;
            "codex@openai-codex" = true;
          };
          env = sandbox.set // {
            ENABLE_CLAUDEAI_MCP_SERVERS = false;
            # suppresses the in-session rating/feedback survey popup
            CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = true;
            # node ships undici as the global `fetch`, which ignores http_proxy and
            # https_proxy unless this is set. The sandbox routes every connection
            # through such a proxy, so without it any node client that uses `fetch`,
            # `eurlex` among them, fails with a bare "fetch failed".
            # node parses this one as a flag value and accepts only "1",
            # a boolean would render as "true" and be ignored.
            NODE_USE_ENV_PROXY = "1";
          };
          worktree = {
            baseRef = "head";
            symlinkDirectories = [ ];
          };
          permissions = {
            defaultMode = "auto";
            disableBypassPermissionsMode = "disable";
            blockReadsOutsideWorkingDirectories = false;
            # `Edit` is the matcher every file-writing built-in is checked against, and an
            # `Edit` allow rule doubles as the sandbox's write grant, so a write path needs
            # stating only here. Claude reads outside the workspace freely, so a `Read`
            # allow rule merely skips the prompt.
            allow =
              mkRules "Read" (withContent sandbox.readPaths)
              ++ mkRules "Edit" (withContent sandbox.writePaths)
              ++ bashRules sandbox.allowedCommands;
            # deny rules cover the built-in tools and are merged into the sandbox boundary,
            # so a single rule blocks both claude itself and any subprocess it spawns. A
            # `Read` deny already stops Edit and Write, but not NotebookEdit, hence the
            # `Edit` rule beside it.
            deny =
              mkRules "Read" (withContent sandbox.deniedPaths)
              ++ mkRules "Edit" (withContent sandbox.deniedPaths)
              # matched on the command line
              ++ bashRules sandbox.deniedCommands;
            ask = [ ];
          };
          statusLine = lib.mkIf (lib.versionAtLeast config.programs.starship.package.version "1.25.0") {
            type = "command";
            command = "${lib.getExe config.programs.starship.package} statusline claude-code";
          };
        };
      };
      programs.agents = {
        harnesses.claude-code = {
          addDirFlag = "--add-dir";
          # nono takes over, merged above the user settings without writing them
          sandboxArgs = [
            "--settings"
            (lib.toJSON { sandbox.enabled = false; })
          ];
          domains = [
            "api.anthropic.com"
            "claude.ai"
            "platform.claude.com"
            # Claude in Chrome, whose extension meets the session on this relay
            "bridge.claudeusercontent.com"
          ];
        };
        # The project config, which claude would otherwise run outside of nono later,
        # except for the prompts, the subagent memory and the worktrees claude creates.
        sandbox.paths = {
          ".claude" = "read";
          ".claude/agent-memory*" = "write";
          ".claude/agents" = "write";
          ".claude/CLAUDE.md" = "write";
          ".claude/commands" = "write";
          ".claude/output-styles" = "write";
          ".claude/rules" = "write";
          ".claude/skills" = "write";
          ".claude/worktrees" = "write";
          # the skills claude syncs from claude.ai within the managed ones, shared by every installation
          "${config.home.homeDirectory}/.claude/skills/synced" = "write";
        };
      };
      programs.nono.profiles.agents = {
        # `.claude.json` stays writable, since claude rewrites it all the time, so an agent
        # could still add an MCP server there that runs without nono later.
        filesystem = {
          allow = [ keychain ];
          # the login of claude, as in the upstream pack, which exposes every item `security` may read
          bypass_protection = [ keychain ];
          allow_file = map (file: "${config.home.homeDirectory}/${file}") [
            ".claude.json"
            ".claude.json.lock"
            ".claude.lock"
          ];
        };
      };
      home.shellAliases = lib.mapAttrs (_name: model: "claude --model ${model}") models;
    };
}
