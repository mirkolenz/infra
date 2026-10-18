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
      inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
    in
    {
      programs.agents = {
        enable = lib.mkDefault config.custom.features.agents.enable;
        context = ./AGENTS.md;
        skills = ./skills;
        sandbox = {
          localhost = true;
          domains.allow = [
            # Every host apart from the denied ones.
            # The allowed ones below are what the skills and tools need once this is dropped.
            "*"
            "github.com"
            "*.github.com"
            "*.githubusercontent.com"
            # nix
            "*.nixos.org"
            "*.cachix.org"
            "*.flakehub.com"
            # my-legal skill: EUR-Lex, CELLAR, the Commission guidance and the CJEU all sit
            # under one domain, and the BSI technical guidelines under the federal one
            "*.europa.eu"
            "www.gesetze-im-internet.de"
            "*.bund.de"
            # my-license skill: the scanoss knowledge base its snippet matching queries.
            # it uploads winnowing fingerprints of the files, never their contents
            "api.osskb.org"
            # my-review, my-legal and my-security skills: the semgrep rule registry,
            # which `--config auto` reads the rules from
            "semgrep.dev"
            # my-security skill: the advisory databases, all of them public read-only feeds.
            # without these the scanners do not fail, they report a clean tree, which is worse
            "*.anchore.io"
            "*.osv.dev"
            "osv-vulnerabilities.storage.googleapis.com"
            "*.deps.dev"
            "vuln.go.dev"
            "*.nist.gov"
            # the sigstore public-good instance, for verifying a release chain
            "*.sigstore.dev"
            # the trivy database, published as an image. its fallback is ghcr.io, which stays
            # denied, so the mirror is what keeps trivy working without reopening that registry
            "mirror.gcr.io"
          ];
          # Package registries, kept shut: an agent that pulls from one is running code
          # nobody reviewed. Denying beats omitting, because an omitted host is still one
          # a per-command request could open. Nix is the deliberate exception, since a
          # flake input is pinned and reviewable.
          domains.deny = [
            "pypi.org"
            "*.pythonhosted.org"
            "registry.npmjs.org"
            # the only registry here that `*.github.com` would otherwise allow
            "npm.pkg.github.com"
            "crates.io"
            "*.crates.io"
            "packagist.org"
            "*.packagist.org"
            "proxy.golang.org"
            # ghcr also serves homebrew bottles
            "*.docker.io"
            "ghcr.io"
            "*.brew.sh"
            # model weights
            "huggingface.co"
            "*.hf.co"
          ];
          # nix talks to the daemon for everything else, the database and the gc roots among it
          paths.read = [
            # the whole store, which the nix daemon serves to every user anyway
            "/nix/store"
            # the system, default and user profiles, through which every tool is on `PATH`
            "/nix/var/nix/profiles"
            config.home.profileDirectory
            # the build logs, which `nix log` reads directly instead of through the daemon
            "/nix/var/log/nix"
            # the trusted flake settings
            "${config.xdg.dataHome}/nix"
            # the user profiles and channels, which nix looks up while evaluating
            "${config.xdg.stateHome}/nix"
            # the git config, without the `credentials` of its credential store
            "${config.xdg.configHome}/git/config"
            "${config.xdg.configHome}/git/ignore"
            "${config.xdg.configHome}/git/attributes"
            # the module cache, the toolchains themselves come from the dev shells
            "${config.home.homeDirectory}/go/pkg/mod"
          ]
          ++ lib.optionals (!config.custom.standalone) [ "/run/current-system/sw" ]
          ++ lib.optionals isDarwin [ "${config.home.homeDirectory}/Library/Fonts" ]
          ++ lib.optionals isLinux [ "${config.xdg.dataHome}/fonts" ];
          paths.write = [
            "${config.home.homeDirectory}/.npm"
            config.xdg.cacheHome
            # nono grants it write-only, but agents and scripts read back what they put there
            "/tmp"
            "${config.xdg.configHome}/.wrangler/logs"
            "${config.xdg.configHome}/.semgrep"
            # codebook downloads its dictionaries here on first use
            "${config.xdg.dataHome}/codebook"
          ]
          # orb would need "${config.home.homeDirectory}/.orbstack" here too
          ++ lib.optionals isDarwin [ "${config.home.homeDirectory}/Library/Caches" ];
          paths.deny = [
            "${config.home.homeDirectory}/.ssh"
            # may hold the token of the host in plaintext, agents get a gh config of their own
            "${config.xdg.configHome}/gh"
            # the netrc, token and socket of determinate-nixd, partly world-readable
            "/nix/var/determinate"
          ];
          # Files that configure code running outside the sandbox later, by git, hook managers,
          # direnv, editors or agents.
          workspace.read = [
            ".git/config"
            ".git/config.worktree"
            ".git/hooks"
            ".git/info"
            # submodules are named after their path, nested ones live in `modules` of their parent
            ".git/modules/**/config"
            ".git/modules/**/hooks"
            ".git/modules/**/info"
            ".git/worktrees/*/config.worktree"
            ".gitmodules"
            ".envrc"
            ".direnv"
            ".devcontainer"
            ".vscode"
            ".zed"
            ".idea"
            ".mcp.json"
          ];
          # the secrets of a project
          workspace.deny = [
            ".env"
            ".env.*"
          ];
          workspace.write = [ ".env.example" ];
          unixSockets = [
            (lib'.nixDaemonSocket pkgs.stdenv)
          ];
          environment.set = {
            ASTRO_TELEMETRY_DISABLED = "1";
            GH_CONFIG_DIR = "${config.xdg.cacheHome}/gh-agents";
            # determinate-nix spawns a sentry crashpad_handler that cannot register its
            # mach bootstrap port inside the sandbox, so disable it to avoid stderr noise
            NIX_SENTRY_ENDPOINT = "";
            GH_PROMPT_DISABLED = "1";
            GH_NO_UPDATE_NOTIFIER = "1";
          };
          environment.unset = [
            # Hides the forwarded agent link from modules/networking/ssh.nix.
            # `IdentityAgent` in ssh_config bypasses the variable, `unixSockets` blocks
            # those sockets, and the keys stay unreadable through their entry in `paths.deny`.
            "SSH_AUTH_SOCK"
          ];
          commands.deny = [
            # would print the keychain, the gh token of the host among it
            "security"
            # keep the injected tokens out of the transcripts, their read-only scope is the boundary
            "gh auth"
            "nix config show"
          ];
        };
      };
    };
}
