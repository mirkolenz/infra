{
  flake.modules.homeManager.default =
    {
      lib,
      lib',
      config,
      pkgs,
      ...
    }:
    {
      programs.agents = {
        context = ./AGENTS.md;
        skills = ./skills;
        sandbox = {
          allowedDomains = [
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
          deniedDomains = [
            "pypi.org"
            "*.pythonhosted.org"
            "registry.npmjs.org"
            # the only registry here that `*.github.com` would otherwise allow
            "npm.pkg.github.com"
            "crates.io"
            "*.crates.io"
            "proxy.golang.org"
            # ghcr also serves homebrew bottles
            "*.docker.io"
            "ghcr.io"
            "*.brew.sh"
            # model weights
            "huggingface.co"
            "*.hf.co"
          ];
          paths = {
            "/nix" = "read";
            "${config.home.homeDirectory}/.npm" = "write";
            "${config.xdg.cacheHome}" = "write";
            "${config.xdg.configHome}/.wrangler/logs" = "write";
            "${config.xdg.configHome}/.semgrep" = "write";
            "${config.home.homeDirectory}/.ssh" = "deny";
          }
          # orb would need "${config.home.homeDirectory}/.orbstack" here too
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            "${config.home.homeDirectory}/Library/Caches" = "write";
          };
          allowedUnixSockets = [
            (lib'.nixDaemonSocket pkgs.stdenv)
          ];
          # Dropping SSH_AUTH_SOCK only removes an agent handed over through the
          # environment, a forwarded one above all. It does not cover the 1Password
          # agent, whose socket ssh takes from `IdentityAgent` in ssh_config, which
          # overrides the variable; `allowedUnixSockets` is what puts that out of
          # reach. Kept for whenever an agent arrives by environment again, and the
          # keys themselves stay unreadable through their `deny` entry in `paths`.
          deniedEnvVars = [
            "SSH_AUTH_SOCK"
          ];
          sessionVariables = {
            ASTRO_TELEMETRY_DISABLED = "1";
            # determinate-nix spawns a sentry crashpad_handler that cannot register its
            # mach bootstrap port inside the sandbox, so disable it to avoid stderr noise
            NIX_SENTRY_ENDPOINT = "";
          };
        };
      };
    };
}
