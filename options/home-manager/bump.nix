# `bump`, which updates the dependencies of the projects at or below the working directory
# and commits them per project and package manager.
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.custom.bump;
  git = lib.getExe config.programs.git.package;
in
{
  options.custom.bump = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          lockfile = mkOption {
            type = types.str;
            description = "Name of the lockfile, whose directories are the roots of the projects using the package manager.";
          };
          pathspecs = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = "Git pathspecs of the files besides the lockfile that the package manager updates, relative to the root of a project.";
          };
          text = mkOption {
            type = types.lines;
            description = ''
              Bash commands updating the dependencies of the project in the working directory,
              which may commit them with the message in `$message`.
            '';
          };
        };
      }
    );
    default = { };
    description = "Package managers of the `bump` command, keyed by their scope in the commit messages.";
  };

  config = lib.mkIf (cfg != { }) {
    custom.commands.bump.text = /* bash */ ''
      # @describe Update the dependencies of the projects at or below the working directory and commit them per project and package manager
      # @arg managers*[${lib.concatStringsSep "|" (lib.attrNames cfg)}]  Package managers, defaulting to all

      # Updates the project in the working directory, given the name of its package manager.
      update() {
        case "$1" in
          ${lib.concatMapAttrsStringSep "\n" (name: manager: ''
            ${name})
              ${manager.text}
              ;;
          '') cfg}
        esac
      }

      # Commits the changed files, given their pathspecs,
      # which are unchanged if they are up to date or the package manager committed them.
      commit() {
        ${git} add -- "$@"

        if ! ${git} diff --cached --quiet -- "$@"; then
          ${git} commit --quiet -m "$message" -- "$@"
        fi
      }

      # Updates and commits the projects of a package manager at or below the working directory,
      # given its name, lockfile, and the pathspecs of the other files it changes.
      # The projects are listed ahead of the updates, which may prompt on the standard input,
      # with parents first, so nested projects such as dev flakes see the updates of their parents.
      # The message names the project by its path in the repository unless it is the root.
      bump() {
        local name=$1 dirs dir
        [ ''${#argc_managers[@]} -eq 0 ] || [[ " ''${argc_managers[*]} " == *" $name "* ]] || return 0
        mapfile -t dirs < <(${git} ls-files -z --cached --others --exclude-standard -- ":(glob)**/$2" | xargs -0 -r dirname | sort -u)

        for dir in "''${dirs[@]}"; do
          (
            cd "$dir"
            prefix="$(${git} rev-parse --show-prefix)"
            message="chore(deps/$name): update''${prefix:+ ''${prefix%/}}"
            update "$name"
            commit "''${@:2}"
          )
        done
      }

      ${lib.concatMapAttrsStringSep "\n" (
        name: manager: "bump ${name} ${lib.escapeShellArgs ([ manager.lockfile ] ++ manager.pathspecs)}"
      ) cfg}
    '';
  };
}
