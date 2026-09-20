{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      agents = config.programs.agents;

      pathsWith = access: lib.attrNames (lib.filterAttrs (_: a: a == access) agents.sandbox.paths);

      # Absolute paths need the `//` prefix, otherwise a rule is read as relative
      # to the project root.
      mkReadRule = path: "Read(/${path}/**)";

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
    lib.mkIf config.custom.features.extras.enable {
      # https://code.claude.com/docs/en/settings-reference
      programs.claude-code = {
        enable = true;
        package = pkgs.claude-code-bin;
        enableMcpIntegration = true;
        settings = {
          autoMemoryEnabled = false;
          cleanupPeriodDays = 30;
          effortLevel = "high";
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
              allowLocalBinding = true;
              allowUnixSockets = agents.sandbox.allowedUnixSockets;
              # `strictAllowlist` is deliberately unset: it would make this list the whole
              # allowlist and have claude refuse the per-command host lists that auto mode
              # sends through the classifier, turning every unforeseen host into a dead end.
              inherit (agents.sandbox) allowedDomains deniedDomains;
            };
            filesystem = {
              allowWrite = pathsWith "write";
              # denyRead = [
              #   ".env*"
              #   "*secret*"
              # ];
            };
            credentials = {
              envVars = map (name: {
                inherit name;
                mode = "deny";
              }) agents.sandbox.deniedEnvVars;
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
          env = agents.sandbox.sessionVariables // {
            # better results, but too many tokens
            # ANTHROPIC_DEFAULT_HAIKU_MODEL = "sonnet";
            ENABLE_CLAUDEAI_MCP_SERVERS = false;
            # subagents fan out, so they dominate token spend. This is the fallback only:
            # a spawn call and an agent's own `model` frontmatter both still win, and
            # CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1 would be what overrides them
            CLAUDE_CODE_SUBAGENT_MODEL = "sonnet";
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
            # claude reads outside the workspace freely, so this only skips the prompt
            allow = map mkReadRule (pathsWith "read");
            # read deny rules cover the built-in tools and are merged into the sandbox boundary,
            # so a single rule blocks both claude itself and any subprocess it spawns
            deny = map mkReadRule (pathsWith "deny");
            ask = [ ];
          };
          statusLine = lib.mkIf (lib.versionAtLeast config.programs.starship.package.version "1.25.0") {
            type = "command";
            command = "${lib.getExe config.programs.starship.package} statusline claude-code";
          };
        };
      };
      # https://code.claude.com/docs/en/model-config
      home.shellAliases = {
        fable = "claude --model fable";
        opus = "claude --model opus";
        sonnet = "claude --model sonnet";
        haiku = "claude --model haiku";
      };
    };
}
