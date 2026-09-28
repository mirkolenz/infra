# `bump`, which updates the dependencies of the current project
# and commits them per package manager.
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
          files = mkOption {
            type = with types; nonEmptyListOf str;
            description = "Files that the package manager updates, whose presence marks the projects using it.";
          };
          text = mkOption {
            type = types.lines;
            description = "Bash commands updating the dependencies in the working directory.";
          };
        };
      }
    );
    default = { };
    description = "Package managers of the `bump` command, keyed by their scope in the commit messages.";
  };

  config = lib.mkIf (cfg != { }) {
    custom.commands.bump.text = /* bash */ ''
      # @describe Update the dependencies of the current project and commit them per package manager
      # @arg managers*[${lib.concatStringsSep "|" (lib.attrNames cfg)}]  Package managers, defaulting to those whose files exist

      # Whether to update a package manager, given its name and files.
      selected() {
        if [ ''${#argc_managers[@]} -gt 0 ]; then
          [[ " ''${argc_managers[*]} " == *" $1 "* ]]
          return
        fi

        for file in "''${@:2}"; do
          if [ ! -e "$file" ]; then
            return 1
          fi
        done
      }

      # Commits the changed files of a package manager, given its name and files,
      # which are unchanged if they are up to date or the package manager committed them.
      commit() {
        ${git} add -- "''${@:2}"

        if ! ${git} diff --cached --quiet -- "''${@:2}"; then
          ${git} commit --quiet -m "chore(deps/$1): update" -- "''${@:2}"
        fi
      }

      ${lib.concatMapAttrsStringSep "\n" (name: manager: ''
        if selected ${name} ${lib.escapeShellArgs manager.files}; then
          ${manager.text}
          commit ${name} ${lib.escapeShellArgs manager.files}
        fi
      '') cfg}
    '';
  };
}
