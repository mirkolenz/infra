# Git remote over the system sshd, with a user locked to git-shell that only allows git transport
# and the helper commands below. Clone with `<user>@<host>:<repo>.git`, `ssh <user>@<host> help` lists the helpers.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.custom.gitShell;

  usage = name: args: lib.concatStringsSep " " ([ name ] ++ map (arg: "<${arg}>") args);

  # `repo` validates a name and prints the path of its repository.
  mkCommand =
    name:
    {
      args ? [ ],
      text,
      ...
    }:
    lib.getExe (
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          cfg.package
        ];
        text = ''
          fail() {
            echo "$*" >&2
            exit 1
          }

          repo() {
            if [[ ! $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
              fail "invalid repository name: $1"
            fi

            echo "''${1%.git}.git"
          }

          if [[ $# -ne ${toString (lib.length args)} ]]; then
            fail "usage: ${usage name args}"
          fi

          ${text}
        '';
      }
    );

  commands = {
    list = {
      description = "list repositories";
      text = ''
        find . -type d -name '*.git' -prune -printf '%P\n' | sort
      '';
    };
    create = {
      args = [ "name" ];
      description = "create a bare repository";
      text = ''
        path=$(repo "$1")
        git init --bare --initial-branch=${cfg.defaultBranch} "$path"
      '';
    };
    delete = {
      args = [ "name" ];
      description = "delete a repository";
      text = ''
        path=$(repo "$1")
        [[ -d $path ]] || fail "no such repository: $1"
        # read -p only prompts on a terminal, but ssh forwards stdin without one too.
        printf 'delete %s? [y/N] ' "$1" >&2
        read -r answer && [[ $answer == y ]] || fail "aborted"
        rm -rf -- "$path"
      '';
    };
    rename = {
      args = [
        "old"
        "new"
      ];
      description = "rename a repository";
      text = ''
        old=$(repo "$1")
        new=$(repo "$2")
        [[ -d $old ]] || fail "no such repository: $1"
        [[ ! -e $new ]] || fail "repository exists: $2"
        mv -T -- "$old" "$new"
      '';
    };
  };

  help.text = lib.concatMapAttrsStringSep "\n" (
    name: command:
    "printf '  %-20s %s\\n' ${
      lib.escapeShellArg (usage name command.args or [ ])
    } ${lib.escapeShellArg command.description}"
  ) commands;

  # git-shell only runs executables from ~/git-shell-commands, with the home dir as cwd,
  # and runs `help` on interactive logins.
  commandsDir = pkgs.linkFarm "git-shell-commands" (
    lib.mapAttrs mkCommand (commands // { inherit help; })
  );
in
{
  options.custom.gitShell = {
    enable = lib.mkEnableOption "a git remote over SSH with git-shell";
    package = lib.mkPackageOption pkgs "gitMinimal" { };
    user = lib.mkOption {
      type = lib.types.str;
      default = "git";
      description = "User that owns the repositories and accepts the SSH logins.";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = cfg.user;
      defaultText = lib.literalExpression "config.custom.gitShell.user";
      description = "Primary group of the user.";
    };
    home = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/git";
      description = "Home directory of the user, which holds the bare repositories.";
    };
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.singleLineStr;
      default = [ ];
      description = "Public SSH keys allowed to access the repositories.";
    };
    defaultBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Initial branch of repositories made by the `create` command.";
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group home;
        createHome = true;
        shell = lib.getExe' cfg.package "git-shell";
        # pty keeps the interactive help prompt, restrict drops all forwarding.
        openssh.authorizedKeys.keys = map (key: "restrict,pty ${key}") cfg.authorizedKeys;
      };
      groups.${cfg.group} = { };
    };

    systemd.tmpfiles.settings.git-shell."${cfg.home}/git-shell-commands"."L+".argument = "${
      commandsDir
    }";
  };
}
