{
  lib,
  pkgs,
  writeShellApplication,
  rsync,
  inputs,
  darwinConfig ? inputs.self.darwinConfigurations.mirkos-macbook,
}:
let
  cfg = darwinConfig.config;
  hmCfg = cfg.home-manager.users.${cfg.system.primaryUser};
  onAct = cfg.homebrew.onActivation;

  # `target` on home.file/xdg.configFile submodules is normalized to a path
  # relative to homeDirectory, so the file's attrname only appears once.
  mkHmFileEntry = label: file: {
    name = label;
    inherit (file) source;
    target = "~/${file.target}";
  };

  brewfile = pkgs.writeText "Brewfile" cfg.homebrew.brewfile;
  brewfileTarget = "~/.config/homebrew/Brewfile";

  # Rebuilt from the same options that nix-darwin's homebrew module reads, so
  # we don't depend on the (internal) string format of onActivation.brewBundleCmd.
  brewBundleCmd = lib.concatStringsSep " " (
    lib.optional (!onAct.autoUpdate) "HOMEBREW_NO_AUTO_UPDATE=1"
    ++ [ "brew bundle --file=${brewfileTarget}" ]
    ++ lib.optional (!onAct.upgrade) "--no-upgrade"
    ++ lib.optional (onAct.cleanup == "uninstall") "--cleanup"
    ++ lib.optional (onAct.cleanup == "zap") "--cleanup --zap"
    ++ onAct.extraFlags
  );

  # Zed rewrites its JSON config at runtime, so it lives outside home.file; copy
  # the source files straight from this flake to the standard XDG location.
  zedDir = ../../modules/programs/zed;
  zedEntries = map (name: {
    name = "Zed ${name}";
    source = builtins.path {
      path = zedDir + "/${name}";
      name = "zed-${name}";
    };
    target = "~/.config/zed/${name}";
  }) (lib.filter (lib.hasSuffix ".json") (lib.attrNames (builtins.readDir zedDir)));

  entries = [
    (mkHmFileEntry "Ghostty config" hmCfg.xdg.configFile."ghostty/config")
    (mkHmFileEntry "SSH config" hmCfg.home.file.".ssh/config")
    {
      name = "Homebrew bundle";
      source = brewfile;
      target = brewfileTarget;
    }
  ]
  ++ zedEntries;

  copyCommands = lib.concatMapStringsSep "\n" (
    e:
    "copy_file ${lib.escapeShellArg e.name} ${lib.escapeShellArg e.source} ${lib.escapeShellArg e.target}"
  ) entries;

  # macOS ships rsync 2.6.9 (no --mkpath), so create parent dirs in one shot
  # before any transfer. Targets are well-known `~/...` paths from this flake.
  remoteParents = lib.unique (map (e: dirOf e.target) entries);
in
writeShellApplication {
  name = "mirkos-macbook-rsync";
  # Intentionally do not pin `openssh` here: the script targets macOS hosts,
  # where the system /usr/bin/ssh is required because user SSH configs use
  # the Apple-only `UseKeychain` option that upstream OpenSSH rejects.
  runtimeInputs = [ rsync ];
  excludeShellChecks = [
    "SC2088" # leading `~` in dst is passed as a literal string; the remote shell expands it
  ];
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

    copy_file() {
      local label=$1 src=$2 dst=$3
      printf '==> %s -> %s:%s\n' "$label" "$remote" "$dst" >&2
      rsync --rsh=ssh --copy-links --human-readable --chmod=u=rw,go= -- "$src" "$remote:$dst"
    }

    ssh "$remote" mkdir -p ${lib.concatStringsSep " " remoteParents}

    ${copyCommands}

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
