{
  config,
  pkgs,
  lib,
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
        excludedCommands = [
          "git *"
          "nix *"
        ];
        network = {
          allowUnixSockets = [
            "/nix/var/nix/daemon-socket/socket"
            ".git/fsmonitor--daemon.ipc"
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
    opus = "claude --model opus";
    sonnet = "claude --model sonnet";
    haiku = "claude --model haiku";
  };
}
