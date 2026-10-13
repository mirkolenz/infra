# Nix settings merged straight into the canonical paths: nix.settings for nixos,
# the installer and standalone home-manager, determinateNix.customSettings for darwin.
# The daemon trusts no user but root, so flake configs and client options cannot
# reconfigure it (https://github.com/archie-judd/agent-sandbox.nix).
# https://nixos.org/manual/nix/unstable/command-ref/conf-file.html#available-settings
let
  # Settings safe to apply unprivileged, shared by home-manager, nixos and darwin.
  unprivilegedSettings = {
    # https://nix.dev/manual/nix/latest/development/experimental-features
    experimental-features = [
      "flakes"
      "nix-command"
      "pipe-operators"
    ];
    nix-path = [
      "nixpkgs=flake:nixpkgs"
    ];
    accept-flake-config = true;
    commit-lock-file-summary = "chore(deps/nix): update";
    fallback = true;
    lint-url-literals = "fatal";
    use-xdg-base-directories = true;
    warn-dirty = false;
  };
  # Daemon-level settings layered on top for the nixos and darwin system configs.
  # Caches an untrusted client may enable through a flake's nixConfig, which picks them per flake.
  sharedSettings = unprivilegedSettings // {
    trusted-substituters = [
      "https://mirkolenz.cachix.org"
      "https://install.determinate.systems"
      "https://recap.cachix.org"
      "https://wi2trier.cachix.org"
      "https://dfki-ebls.cachix.org"
    ];
    extra-trusted-public-keys = [
      "mirkolenz.cachix.org-1:R0dgCJ93t33K/gncNbKgUdJzwgsYVXeExRsZNz5jpho="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "recap.cachix.org-1:KElwRDtaJbbQxmmS2SyxWHqs9bdJbaZHzb2iINTfQws="
      "wi2trier.cachix.org-1:8wJvKtRD8XUqYZMdjECTsN1zWxHy9kvp5aoPQiAm1fY="
      "dfki-ebls.cachix.org-1:hImWYLrtbzgibnK8e09XXT2EID923m6D08fHmASB/kE="
    ];
    auto-optimise-store = true;
    download-buffer-size = 1000 * 1000 * 1000; # 1 GB
    keep-derivations = true;
    keep-failed = false;
    keep-going = true;
    keep-outputs = false;
    log-lines = 200;
  };
in
{
  flake.modules.nixos.base.nix.settings = sharedSettings // {
    allowed-users = [ "@wheel" ];
    sandbox = true;
  };

  # The live system runs as root, so the daemon-level settings apply as well.
  flake.modules.nixos.installer.nix.settings = sharedSettings;

  flake.modules.darwin.base.determinateNix.customSettings = sharedSettings // {
    allowed-users = [ "@admin" ];
    sandbox = false;
  };

  flake.modules.homeManager.standalone.nix.settings = unprivilegedSettings // {
    bash-prompt-prefix = "(nix:$name)\\040";
    # log-lines = 200; # https://github.com/nixos/nix/issues/13399
  };
}
