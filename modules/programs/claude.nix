{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      lib',
      ...
    }:
    lib.mkIf config.custom.features.withOptionals {
      # https://code.claude.com/docs/en/permissions
      # https://code.claude.com/docs/en/sandboxing
      # https://code.claude.com/docs/en/settings
      # https://www.schemastore.org/claude-code-settings.json
      programs.claude-code = {
        enable = true;
        package = pkgs.claude-code-bin;
        enableMcpIntegration = true;
        settings = {
          autoMemoryEnabled = false;
          cleanupPeriodDays = 30;
          effortLevel = "xhigh";
          enableAllProjectMcpServers = true;
          forceLoginMethod = "claudeai";
          includeCoAuthoredBy = false;
          includeGitInstructions = false;
          skipAutoPermissionPrompt = true;
          spinnerTipsEnabled = false;
          sandbox = {
            enabled = true;
            allowLocalBinding = true;
            allowUnsandboxedCommands = true;
            enableWeakerNetworkIsolation = true;
            network = {
              allowUnixSockets = [
                (lib'.nixDaemonSocket pkgs.stdenv)
              ]
              # orb talks to the OrbStack daemon over the sockets under this dir, darwin only
              ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
                "${config.home.homeDirectory}/.orbstack/run"
              ];
              allowedDomains = [
                "github.com"
                "api.github.com"
                "raw.githubusercontent.com"
                "pypi.org"
                "files.pythonhosted.org"
                "huggingface.co"
                "registry.npmjs.org"
                "api.npmjs.org"
                "ui.shadcn.com"
              ];
            };
            # absolute paths need // prefix, otherwise they are treated as relative to the project root
            filesystem = {
              allowWrite = [
                "/${config.home.homeDirectory}/.npm"
                "/${config.home.homeDirectory}/Library/Caches"
                "/${config.xdg.cacheHome}"
                "/${config.xdg.configHome}/.wrangler/logs"
              ]
              # orb stores logs, sockets, and state here and reads them on every call, darwin only
              ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
                "/${config.home.homeDirectory}/.orbstack"
              ];
              # denyRead = [
              #   ".env*"
              #   "*secret*"
              # ];
            };
          };
          extraKnownMarketplaces = {
            claude-plugins-official = {
              source = {
                source = "github";
                repo = "anthropics/claude-plugins-official";
              };
            };
            openai-codex = {
              source = {
                source = "github";
                repo = "openai/codex-plugin-cc";
              };
            };
          };
          enabledPlugins = {
            "code-simplifier@claude-plugins-official" = true;
            "feature-dev@claude-plugins-official" = true;
            "frontend-design@claude-plugins-official" = true;
            "codex@openai-codex" = true;
          };
          env = {
            # better results, but too many tokens
            # ANTHROPIC_DEFAULT_HAIKU_MODEL = "sonnet";
            ENABLE_CLAUDEAI_MCP_SERVERS = false;
            ASTRO_TELEMETRY_DISABLED = true;
            # determinate-nix spawns a sentry crashpad_handler that cannot register its
            # mach bootstrap port inside the sandbox, so disable it to avoid stderr noise
            NIX_SENTRY_ENDPOINT = "";
          };
          worktree = {
            baseRef = "head";
            symlinkDirectories = [ ];
          };
          permissions = {
            defaultMode = "auto";
            disableBypassPermissionsMode = "disable";
            allow = [
              "WebFetch"
              "WebSearch"
              "Write(//nix/**/*)"
            ];
            deny = [ ];
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
