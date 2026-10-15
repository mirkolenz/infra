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
            description = "Path of the lockfile relative to the root of a project, which marks the projects using the package manager.";
          };
          excludes = mkOption {
            type = with types; listOf str;
            default = [ ];
            example = [ "**/testdata/**" ];
            description = "Glob patterns of the lockfiles that belong to no project of their own, such as test fixtures.";
          };
          pathspecs = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = "Git pathspecs of the files besides the lockfile that the package manager updates, relative to the root of a project, which may match no file.";
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

      # The tracked and untracked files at or below the working directory matching the pathspecs, null-separated.
      files() {
        ${git} ls-files -z --cached --others --exclude-standard -- "$@"
      }

      # Commits the changed files, given their pathspecs, which are unchanged if they are up to date.
      # Pathspecs may match no file, such as optional manifests, since git only adds the files they match.
      # A package manager may commit its lockfile itself, which then takes up the remaining changes.
      commit() {
        local files message_args=(-m "$message")
        mapfile -d "" -t files < <(files "$@")
        ${git} add -- "''${files[@]}"

        if ${git} diff --cached --quiet -- "''${files[@]}"; then
          return
        fi

        if [ "$(${git} rev-parse HEAD)" != "$head" ]; then
          message_args=(--amend --no-edit)
        fi

        ${git} commit --quiet "''${message_args[@]}" -- "''${files[@]}"
      }

      # Updates and commits the projects of a package manager at or below the working directory,
      # given its name, lockfile, and the pathspecs of the other files it changes,
      # skipping the lockfiles matched by the exclude pathspecs in `excludes`.
      # The lockfiles are listed ahead of the updates, which may prompt on the standard input,
      # and each project commits right away, so a parent never sweeps up the changes of a nested one.
      # The message names the project by its path in the repository unless it is the root.
      bump() {
        local name=$1 lockfile=$2 paths path
        [ ''${#argc_managers[@]} -eq 0 ] || [[ " ''${argc_managers[*]} " == *" $name "* ]] || return 0
        mapfile -d "" -t paths < <(files ":(glob)**/$lockfile" "''${excludes[@]}")

        for path in "''${paths[@]}"; do
          (
            cd "''${path%"$lockfile"}."
            prefix="$(${git} rev-parse --show-prefix)"
            message="chore(deps/$name): update''${prefix:+ ''${prefix%/}}"
            head="$(${git} rev-parse HEAD)"
            update "$name"
            commit "''${@:2}"
          )
        done
      }

      ${lib.concatMapAttrsStringSep "\n" (name: manager: ''
        excludes=(${lib.escapeShellArgs (map (pattern: ":(exclude,glob)${pattern}") manager.excludes)})
        bump ${name} ${lib.escapeShellArgs ([ manager.lockfile ] ++ manager.pathspecs)}
      '') cfg}
    '';
  };
}
