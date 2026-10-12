{
  flake.modules.homeManager.default =
    {
      lib,
      lib',
      config,
      pkgs,
      ...
    }:
    let
      # the protected entries of every harness in each of its state directories
      protected = lib.concatMap (
        harness:
        lib.mapCartesianProduct ({ dir, entry }: "${dir}/${entry}") {
          dir = harness.stateDirs;
          entry = harness.protectedEntries;
        }
      ) (lib.attrValues config.programs.agents.harnesses);
    in
    {
      programs.agents = {
        enable = lib.mkDefault config.custom.features.extras.enable;
        context = ./AGENTS.md;
        skills = ./skills;
        sandbox = {
          domains = {
            "github.com" = "allow";
            "*.github.com" = "allow";
            "*.githubusercontent.com" = "allow";
            # nix
            "*.nixos.org" = "allow";
            "*.cachix.org" = "allow";
            "*.flakehub.com" = "allow";
            # my-legal skill: EUR-Lex, CELLAR, the Commission guidance and the CJEU all sit
            # under one domain, and the BSI technical guidelines under the federal one
            "*.europa.eu" = "allow";
            "www.gesetze-im-internet.de" = "allow";
            "*.bund.de" = "allow";
            # my-license skill: the scanoss knowledge base its snippet matching queries.
            # it uploads winnowing fingerprints of the files, never their contents
            "api.osskb.org" = "allow";
            # my-review, my-legal and my-security skills: the semgrep rule registry,
            # which `--config auto` reads the rules from
            "semgrep.dev" = "allow";
            # my-security skill: the advisory databases, all of them public read-only feeds.
            # without these the scanners do not fail, they report a clean tree, which is worse
            "*.anchore.io" = "allow";
            "*.osv.dev" = "allow";
            "osv-vulnerabilities.storage.googleapis.com" = "allow";
            "*.deps.dev" = "allow";
            "vuln.go.dev" = "allow";
            "*.nist.gov" = "allow";
            # the sigstore public-good instance, for verifying a release chain
            "*.sigstore.dev" = "allow";
            # the trivy database, published as an image. its fallback is ghcr.io, which stays
            # denied, so the mirror is what keeps trivy working without reopening that registry
            "mirror.gcr.io" = "allow";

            # Package registries, kept shut: an agent that pulls from one is running code
            # nobody reviewed. Denying beats omitting, because an omitted host is still one
            # a per-command request could open. Nix is the deliberate exception, since a
            # flake input is pinned and reviewable.
            "pypi.org" = "deny";
            "*.pythonhosted.org" = "deny";
            "registry.npmjs.org" = "deny";
            # the only registry here that `*.github.com` would otherwise allow
            "npm.pkg.github.com" = "deny";
            "crates.io" = "deny";
            "*.crates.io" = "deny";
            "proxy.golang.org" = "deny";
            # ghcr also serves homebrew bottles
            "*.docker.io" = "deny";
            "ghcr.io" = "deny";
            "*.brew.sh" = "deny";
            # model weights
            "huggingface.co" = "deny";
            "*.hf.co" = "deny";
          };
          paths = {
            "/nix" = "read";
            # tool state that the agents confining reads would otherwise miss
            "${config.xdg.configHome}/git" = "read";
            "${config.xdg.configHome}/uv" = "read";
            # hook environments that run outside the sandbox later, the agents get their own below
            "${config.xdg.cacheHome}/pre-commit" = "read";
            "${config.home.homeDirectory}/.npm" = "write";
            "${config.xdg.cacheHome}" = "write";
            "${config.xdg.configHome}/.wrangler/logs" = "write";
            "${config.xdg.configHome}/.semgrep" = "write";
            # codebook downloads its dictionaries here on first use
            "${config.xdg.dataHome}/codebook" = "write";
            "${config.home.homeDirectory}/.ssh" = "deny";
            # may hold the token of the host in plaintext, agents get a gh config of their own
            "${config.xdg.configHome}/gh" = "deny";
            # the netrc, token and socket of determinate-nixd, partly world-readable
            "/nix/var/determinate" = "deny";
            # Files that configure code running outside the sandbox later, by git, hook managers,
            # direnv, editors or agents, and the secrets of a project.
            ".git/config" = "read";
            ".git/config.worktree" = "read";
            ".git/hooks" = "read";
            ".git/info" = "read";
            # submodules are named after their path, nested ones live in `modules` of their parent
            ".git/modules/**/config" = "read";
            ".git/modules/**/hooks" = "read";
            ".git/modules/**/info" = "read";
            ".git/worktrees/*/config.worktree" = "read";
            ".gitmodules" = "read";
            ".pre-commit-config.yaml" = "read";
            ".husky" = "read";
            "lefthook.yml" = "read";
            ".envrc" = "read";
            ".direnv" = "read";
            ".devcontainer" = "read";
            ".vscode" = "read";
            ".zed" = "read";
            ".idea" = "read";
            ".mcp.json" = "read";
            ".env" = "deny";
            ".env.*" = "deny";
            ".env.example" = "write";
          }
          # orb would need "${config.home.homeDirectory}/.orbstack" here too
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            "${config.home.homeDirectory}/Library/Caches" = "write";
          }
          // lib.genAttrs protected (_: "read");
          unixSockets = [
            (lib'.nixDaemonSocket pkgs.stdenv)
          ];
          environment = {
            # Hides the forwarded agent link from modules/networking/ssh.nix.
            # `IdentityAgent` in ssh_config bypasses the variable, `unixSockets` blocks
            # those sockets, and the keys stay unreadable through their `deny` entry in `paths`.
            SSH_AUTH_SOCK = null;
            ASTRO_TELEMETRY_DISABLED = "1";
            PRE_COMMIT_HOME = "${config.xdg.cacheHome}/pre-commit-agents";
            GH_CONFIG_DIR = "${config.xdg.cacheHome}/gh-agents";
            # determinate-nix spawns a sentry crashpad_handler that cannot register its
            # mach bootstrap port inside the sandbox, so disable it to avoid stderr noise
            NIX_SENTRY_ENDPOINT = "";
            GH_PROMPT_DISABLED = "1";
            GH_NO_UPDATE_NOTIFIER = "1";
          };
          commands = {
            # would print the keychain, the gh token of the host among it
            security = "deny";
            # keep the injected tokens out of the transcripts, their read-only scope is the boundary
            "gh auth" = "deny";
            "nix config show" = "deny";
          };
        };
      };
    };
}
