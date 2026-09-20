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
              strictAllowlist = true;
              allowUnixSockets = [
                (lib'.nixDaemonSocket pkgs.stdenv)
              ];
              # orb talks to the OrbStack daemon over the sockets under this dir, darwin only
              # ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
              #   "${config.home.homeDirectory}/.orbstack/run"
              # ];
              allowedDomains = [
                "github.com"
                "api.github.com"
                "raw.githubusercontent.com"
                # the `lgl` skill reads the consolidated texts: eurlex resolves through
                # eur-lex and downloads Formex from CELLAR, recht reads the German corpus
                "eur-lex.europa.eu"
                "publications.europa.eu"
                "www.gesetze-im-internet.de"
                # codes of practice and Commission guidelines
                "digital-strategy.ec.europa.eu"
                # the newsroom redirects those pdfs go through
                "ec.europa.eu"
                # EDPB guidelines and opinions
                "www.edpb.europa.eu"
                # BSI technical guidelines such as TR-03183
                "www.bsi.bund.de"
                # CJEU judgments
                "curia.europa.eu"
                # "pypi.org"
                # "files.pythonhosted.org"
                # "huggingface.co"
                # "registry.npmjs.org"
                # "api.npmjs.org"
                # "ui.shadcn.com"
              ];
            };
            filesystem = {
              allowWrite = [
                "${config.home.homeDirectory}/.npm"
                "${config.home.homeDirectory}/Library/Caches"
                "${config.xdg.cacheHome}"
                "${config.xdg.configHome}/.wrangler/logs"
              ];
              # orb stores logs, sockets, and state here and reads them on every call, darwin only
              # ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
              #   "${config.home.homeDirectory}/.orbstack"
              # ];
              # denyRead = [
              #   ".env*"
              #   "*secret*"
              # ];
            };
            credentials = {
              # ssh keys are blocked via permissions.deny, which also covers the built-in tools.
              # Dropping SSH_AUTH_SOCK only removes an agent handed over through the
              # environment, a forwarded one above all. It does not cover the 1Password
              # agent, whose socket ssh takes from `IdentityAgent` in ssh_config, which
              # overrides the variable; the unix socket allowlist above is what puts that
              # out of reach. Kept for whenever an agent arrives by environment again.
              envVars = [
                {
                  name = "SSH_AUTH_SOCK";
                  mode = "deny";
                }
              ];
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
          env = {
            # better results, but too many tokens
            # ANTHROPIC_DEFAULT_HAIKU_MODEL = "sonnet";
            ENABLE_CLAUDEAI_MCP_SERVERS = false;
            # subagents fan out, so they dominate token spend. This is the fallback only:
            # a spawn call and an agent's own `model` frontmatter both still win, and
            # CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1 would be what overrides them
            CLAUDE_CODE_SUBAGENT_MODEL = "sonnet";
            # suppresses the in-session rating/feedback survey popup
            CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = true;
            ASTRO_TELEMETRY_DISABLED = true;
            # determinate-nix spawns a sentry crashpad_handler that cannot register its
            # mach bootstrap port inside the sandbox, so disable it to avoid stderr noise
            NIX_SENTRY_ENDPOINT = "";
          };
          worktree = {
            baseRef = "head";
            symlinkDirectories = [ ];
          };
          # absolute paths need // prefix, otherwise they are treated as relative to the project root
          permissions = {
            defaultMode = "auto";
            disableBypassPermissionsMode = "disable";
            blockReadsOutsideWorkingDirectories = false;
            allow = [
              "Read(//nix/**)"
            ];
            # read deny rules cover the built-in tools and are merged into the sandbox boundary,
            # so a single rule blocks both claude itself and any subprocess it spawns
            deny = [
              "Read(~/.ssh/**)"
            ];
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
