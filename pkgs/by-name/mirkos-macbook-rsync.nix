{
  lib,
  writeShellApplication,
  rsync,
  self,
}:
let
  brewBundleCmd = "brew bundle --file=~/.config/homebrew/Brewfile";
in
writeShellApplication {
  name = "mirkos-macbook-rsync";
  # Intentionally do not pin `nix` or `openssh` here: `nix` has to match the
  # local daemon, and the script targets macOS hosts, where the system
  # /usr/bin/ssh is required because user SSH configs use the Apple-only
  # `UseKeychain` option that upstream OpenSSH rejects.
  runtimeInputs = [ rsync ];
  text = ''
    if [[ $# -ne 1 ]]; then
      cat <<'USAGE' >&2
    Usage: mirkos-macbook-rsync [user@]host

    Copies select configuration files derived from
    darwinConfigurations.mirkos-macbook to a remote macOS host via rsync over
    SSH. Useful for bootstrapping macOS machines that do not have Nix
    installed.
    USAGE
      exit 1
    fi

    remote=$1

    # Built on demand so that this script stays cheap to evaluate: nothing here
    # forces an evaluation of the darwin configuration.
    src=$(nix build --no-link --print-out-paths \
      ${lib.escapeShellArg "${self}#darwinConfigurations.mirkos-macbook.config.system.build.remoteConfig"})

    # macOS ships rsync 2.6.9, but --chmod is applied by the sending side, so the
    # modern local rsync handles it; a recursive transfer also creates the remote
    # parent directories without the (unsupported) --mkpath. Without --perms the
    # modes apply to newly created entries only, leaving the remote home
    # directory and any pre-existing directory untouched.
    rsync --rsh=ssh --recursive --copy-links --verbose --chmod=D755,F600 -- "$src/" "$remote:"

    cat <<EOF

    All files copied to $remote.
    Apply the Homebrew bundle by running on $remote:

      ${brewBundleCmd}

    Or remotely from this machine:

      ssh $remote "${brewBundleCmd}"
    EOF
  '';
  meta = {
    description = "Copy mirkos-macbook configs (Ghostty, SSH, Homebrew bundle) to a remote macOS host";
    mainProgram = "mirkos-macbook-rsync";
    platforms = lib.platforms.darwin;
  };
}
