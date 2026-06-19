# Nix settings merged straight into the canonical paths: nix.settings for nixos
# and standalone home-manager, determinateNix.customSettings for darwin.
# https://nixos.org/manual/nix/unstable/command-ref/conf-file.html#available-settings
let
  # Settings safe to apply unprivileged, shared by home-manager, nixos and darwin.
  unprivilegedSettings = {
    # https://nix.dev/manual/nix/latest/development/experimental-features
    experimental-features = [
      "flakes"
      "impure-derivations"
      "nix-command"
      "pipe-operators"
    ];
    nix-path = [
      "nixpkgs=flake:pkgs"
    ];
    accept-flake-config = true;
    commit-lock-file-summary = "chore(deps/nix): update";
    fallback = true;
    lint-url-literals = "fatal";
    use-xdg-base-directories = true;
    warn-dirty = false;
  };
  # Daemon-level settings layered on top for the nixos and darwin system configs.
  sharedSettings = unprivilegedSettings // {
    auto-optimise-store = true;
    download-buffer-size = 1000000000; # 1 GB
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

  flake.modules.darwin.base.determinateNix.customSettings = sharedSettings // {
    allowed-users = [ "@admin" ];
    trusted-users = [ "@admin" ];
    sandbox = false;
  };

  flake.modules.homeManager.standalone.nix.settings = unprivilegedSettings // {
    bash-prompt-prefix = "(nix:$name)\\040";
    # log-lines = 200; # https://github.com/nixos/nix/issues/13399
  };
}
