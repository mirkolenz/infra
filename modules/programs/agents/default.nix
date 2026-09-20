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
        enable = true;
        instructions = ./AGENTS.md;
        sandbox = {
          allowedDomains = [
            "github.com"
            "*.github.com"
            "*.githubusercontent.com"
            # nix
            "*.nixos.org"
            "*.cachix.org"
            "*.flakehub.com"
            # hm-legal skill
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

        skills = lib.mkIf config.custom.features.extras.enable ./skills;
      };
    };
}
