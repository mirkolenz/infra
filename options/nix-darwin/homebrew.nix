# Installs Homebrew itself from a pinned source instead of the official installer.
# Formulae and casks of the official taps come from Homebrew's API,
# third-party taps are pinned like Homebrew itself.
# As in the upstream layout, the prefix doubles as the repository,
# but its code directories link into the store.
# bin/brew is a copy since brew derives the repository from its location,
# and refuses to run unless the repository is writable.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homebrew.install;
  inherit (config.homebrew) prefix user;
  rev = cfg.src.rev or "pinned";
  vendor = "${cfg.src}/Library/Homebrew/vendor";
  # the portable ruby that brew would download on its first run, pinned by its checksum
  rubyInfo = lib.readFile "${vendor}/portable-ruby-${pkgs.stdenv.hostPlatform.darwinArch}-darwin";
  rubySha = lib.head (lib.match ".*ruby_SHA=([0-9a-f]{64}).*" rubyInfo);
  portableRuby = pkgs.fetchurl {
    name = "portable-ruby.tar.gz";
    url = "https://ghcr.io/v2/homebrew/core/portable-ruby/blobs/sha256:${rubySha}";
    sha256 = rubySha;
    # ghcr requires a token even for public packages, brew uses the same anonymous one
    curlOptsList = [
      "--header"
      "Authorization: Bearer QQ=="
    ];
  };
in
{
  options.homebrew.install = {
    enable = lib.mkEnableOption "installing Homebrew from a pinned source";
    src = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression "inputs.brew";
      description = "Source of Homebrew, such as a flake input of `github:homebrew/brew`.";
    };
    taps = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression ''{ "user/repo" = inputs.homebrew-repo; }'';
      description = ''
        Third-party taps by name, such as flake inputs of their repositories.
        They are trusted and declared in `homebrew.taps`.
        Homebrew's API serves the official taps.
      '';
    };
    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example.HOMEBREW_NO_ENV_HINTS = "1";
      description = "Variables that Homebrew loads on every invocation.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Library, completions, and manual pages of the pinned Homebrew.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.install.package =
      pkgs.runCommandLocal "homebrew" { nativeBuildInputs = [ pkgs.installShellFiles ]; }
        ''
          mkdir $out
          cp -r ${cfg.src}/Library $out
          chmod -R u+w $out/Library
          # outside of the repository, which keeps brew from linking its own copies into the prefix
          installShellCompletion --cmd brew \
            --bash ${cfg.src}/completions/bash/brew \
            --fish ${cfg.src}/completions/fish/brew.fish \
            --zsh ${cfg.src}/completions/zsh/_brew
          installManPage ${cfg.src}/manpages/brew.1

          tar -xzf ${portableRuby} -C $out/Library/Homebrew/vendor
          ln -s $(< ${vendor}/portable-ruby-version) $out/Library/Homebrew/vendor/portable-ruby/current

          # `brew update` would turn the prefix into a git checkout that replaces the pinned code.
          # Without it, the update skips the repository and taps, but still updates the formula and cask data.
          # Its failure logs and the donation notice that it shows once depend on the missing git metadata.
          substituteInPlace $out/Library/Homebrew/cmd/update.sh \
            --replace-fail "  git_init_if_necessary" "" \
            --replace-fail '"''${HOMEBREW_REPOSITORY}/.git/' '"''${HOMEBREW_CACHE}/'
          substituteInPlace $out/Library/Homebrew/cmd/update-report.rb \
            --replace-fail "  donation_message" ""

          # copies, since brew only loads packages whose real path is inside its taps directory
          ${lib.concatMapAttrsStringSep "\n" (name: src: ''
            mkdir -p $out/Library/Taps/${dirOf name}
            cp -r ${src} $out/Library/Taps/${dirOf name}/homebrew-${baseNameOf name}
          '') cfg.taps}
        '';
    homebrew.install.env = {
      # brew reads these revisions from the git metadata of its repository otherwise
      HOMEBREW_VERSION = lib.mkDefault rev;
      HOMEBREW_UPDATE_BEFORE = rev;
      HOMEBREW_UPDATE_AFTER = rev;
      # brew stores its settings in the git config of its repository
      HOMEBREW_NO_ANALYTICS = "1";
      HOMEBREW_NO_ANALYTICS_MESSAGE_OUTPUT = "1";
      # loads this file last, so that the user and prefix files cannot override it
      HOMEBREW_SYSTEM_ENV_TAKES_PRIORITY = "1";
    };
    # declared so that the cleanup keeps them
    homebrew.taps = lib.mapAttrsToList (name: _: {
      inherit name;
      trusted = true;
    }) cfg.taps;

    environment.etc."homebrew/brew.env".text = lib.generators.toKeyValue { } cfg.env;
    environment.systemPackages = [ cfg.package ];

    system.checks.text = lib.mkBefore ''
      # the activation would link into the directory instead of replacing it
      if [[ -d ${prefix}/Library && ! -L ${prefix}/Library ]]; then
        printf >&2 '\e[1;31merror: ${prefix} contains a git checkout of Homebrew, aborting activation\e[0m\n'
        printf >&2 'Remove it while keeping the installed packages:\n'
        printf >&2 '\n'
        printf >&2 '    git -C ${prefix} rm -r --force --quiet .\n'
        printf >&2 '    rm -rf ${prefix}/{.git,Library,completions,manpages}\n'
        printf >&2 '    find -L ${prefix}/{etc,share} -type l -exec rm {} +\n'
        printf >&2 '\n'
        exit 2
      fi
      # bin/brew is installed during the activation
      INSTALLING_HOMEBREW=1
    '';
    system.activationScripts.homebrew.text = lib.mkBefore ''
      echo >&2 "setting up Homebrew..."
      install -d -o ${user} -g admin -m 755 ${prefix}
      install -d -o ${user} -g admin -m 775 ${prefix}/bin
      install -o ${user} -g admin -m 755 ${cfg.src}/bin/brew ${prefix}/bin/brew
      ln -sfn ${cfg.package}/Library ${prefix}/Library
    '';
  };
}
