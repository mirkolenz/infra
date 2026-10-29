{ lib', ... }:
{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;

      # A skill fails to build unless it follows the spec and its `SKILL.md` passes the
      # hard rules of simplified technical english. skills-ref matches the name against
      # the directory, which in the store carries a hash.
      mkSkill =
        name: _:
        pkgs.runCommandLocal name
          {
            nativeBuildInputs = with pkgs; [
              skills-ref
              ste-lint
            ];
          }
          ''
            cp -r ${./skills + "/${name}"} ${name}
            skills-ref validate ${name}
            ste-lint ${name}/SKILL.md
            cp -r ${name} $out
          '';
    in
    {
      programs.agents = {
        enable = lib.mkDefault config.custom.features.agents.enable;
        context = ./AGENTS.md;
        skills = lib.mapAttrs mkSkill (lib.readDir ./skills);
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
            "vuln.go.dev"
            "*.nist.gov"
            # the sigstore public-good instance, for verifying a release chain
            "*.sigstore.dev"
            # the trivy database, published as an image. its fallback is ghcr.io, which stays
            # denied, so the mirror is what keeps trivy working without reopening that registry
            "mirror.gcr.io"
            # the package metadata of the registries denied below, see AGENTS.md,
            # and the dependency graphs the my-security skill reads
            "*.deps.dev"
          ];
          # Package registries with their mirrors, CDNs and toolchain installers, kept shut:
          # an agent that pulls from one is running code nobody reviewed. Denying beats omitting,
          # because an omitted host is still one a per-command request could open. Nix is the
          # deliberate exception, since a flake input is pinned and reviewable. deps.dev covers
          # the metadata of npm, PyPI, crates.io, Go, Maven, NuGet and RubyGems.
          # Checked against the hosts the Copilot cloud agent needs to install packages,
          # https://docs.github.com/en/copilot/reference/copilot-allowlist-reference,
          # leaving out its documentation sites, OS package repositories and path-scoped entries.
          domains.deny = [
            # GitHub Packages of every ecosystem, which `*.github.com` would otherwise allow
            "*.pkg.github.com"
            # python
            "pypi.org"
            "pypi.python.org"
            "*.pythonhosted.org"
            "bootstrap.pypa.io"
            "download.pytorch.org"
            "anaconda.org"
            "*.anaconda.org"
            "repo.anaconda.com"
            "repo.continuum.io"
            "binstar.org"
            "*.binstar.org"
            "*.prefix.dev"
            # javascript
            "registry.npmjs.org"
            "registry.npmjs.com"
            "registry.yarnpkg.com"
            "repo.yarnpkg.com"
            "*.npmmirror.com"
            "registry.bower.io"
            "pkg.pr.new"
            "jsr.io"
            "*.jsr.io"
            "deno.land"
            "unpkg.com"
            "cdn.jsdelivr.net"
            "esm.sh"
            "cdn.skypack.dev"
            "ga.jspm.io"
            "get.pnpm.io"
            "bun.sh"
            "binaries.prisma.sh"
            # rust
            "crates.io"
            "*.crates.io"
            "sh.rustup.rs"
            "static.rust-lang.org"
            # go
            "proxy.golang.org"
            "goproxy.io"
            "goproxy.cn"
            # jvm
            "repo.maven.apache.org"
            "repo1.maven.org"
            "search.maven.org"
            "maven-central.storage-download.googleapis.com"
            "maven.google.com"
            "maven.oracle.com"
            "oss.sonatype.org"
            "repo.spring.io"
            "repo.grails.org"
            "plugins.gradle.org"
            "plugins-artifacts.gradle.org"
            "services.gradle.org"
            # dotnet
            "nuget.org"
            "*.nuget.org"
            "nugetregistryv2prod.blob.core.windows.net"
            "pkgs.dev.azure.com"
            "builds.dotnet.microsoft.com"
            "dotnetcli.azureedge.net"
            "dotnetcli.blob.core.windows.net"
            "ci.dot.net"
            # ruby
            "rubygems.org"
            "*.rubygems.org"
            "gems.rubyonrails.org"
            "cache.ruby-lang.org"
            "*.rvm.io"
            # registries beyond deps.dev
            "packagist.org"
            "*.packagist.org"
            "getcomposer.org"
            "hex.pm"
            "*.hex.pm"
            "pub.dev"
            "pub.dartlang.org"
            "hackage.haskell.org"
            "*.hackage.haskell.org"
            "get-ghcup.haskell.org"
            "downloads.haskell.org"
            "cpan.org"
            "www.cpan.org"
            "cpan.metacpan.org"
            "cdn.cocoapods.org"
            "download.swift.org"
            # container images, ghcr also serves homebrew bottles
            "*.docker.io"
            "registry.hub.docker.com"
            "production.cloudflare.docker.com"
            "ghcr.io"
            "quay.io"
            "gcr.io"
            "mcr.microsoft.com"
            "public.ecr.aws"
            "*.brew.sh"
            # infrastructure tools and their package sources
            "releases.hashicorp.com"
            "*.releases.hashicorp.com"
            "registry.terraform.io"
            "dl.k8s.io"
            "pkgs.k8s.io"
            "packagecloud.io"
            "packages.cloud.google.com"
            "packages.microsoft.com"
            # browsers, the preinstalled ones are the only ones to use
            "playwright.download.prss.microsoft.com"
            "cdn.playwright.dev"
            "playwright.azureedge.net"
            "playwright-akamai.azureedge.net"
            "playwright-verizon.azureedge.net"
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
            "${config.xdg.configHome}/.wrangler"
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
