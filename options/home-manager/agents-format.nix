# Formats the files the coding agents edit with treefmt, configured like the global formatter of
# pkgs/by-name/treefmt-nix.nix, with every language of options/shared/_editors of the extras.
# Each edit gets formatted, and at the end of a turn the changed files of the git repository get
# fixed and formatted once more, since fixing mid-edit could drop an import that the next edit
# is about to use. Remaining lints count as failures.
# Only harnesses with native support are wired up: Claude Code and Codex through their
# hooks, opencode through its formatters.
{ lib, pkgs, ... }:
let
  treefmt = pkgs.treefmt-nix.config;
  languages = treefmt.custom.active.languages;

  formatters = lib.unique (
    lib.remove null (lib.mapAttrsToList (_: language: language.formatter.tool) languages)
  );

  script = pkgs.writeShellApplication {
    name = "agent-format";
    runtimeInputs = with pkgs; [
      git
      jq
    ];
    text = ''
      # agent-format FILE...       formats the files, for opencode
      # agent-format --post-tool   formats the files of an edit hook
      # agent-format --stop        fixes and formats the changed files of the git repository

      failures=()

      # Runs treefmt on files below a root, and records a failure.
      run() {
        local root=$1 output
        shift
        if ! output=$(${lib.getExe treefmt.package} --config-file ${treefmt.build.configFile} --tree-root "$root" \
          --walk filesystem --no-cache --quiet --on-unmatched debug "$@" 2>&1); then
          failures+=("''${output:0:2000}")
        fi
      }

      # Formats each file below its git repository, or else its directory.
      format() {
        local file root
        for file in "$@"; do
          [[ -f $file ]] || continue
          root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null) || root=$(dirname "$file")
          run "$root" --formatters ${lib.concatStringsSep "," formatters} "$file"
        done
      }

      mode=''${1:-}
      case $mode in
      --post-tool)
        # The edited files of Claude Code, and of the patches of Codex.
        mapfile -t files < <(jq -r '
          (.cwd // ".") as $cwd
          | (.tool_input.file_path // empty),
            (.tool_input.command // empty | strings | split("\n")[]
              | capture("^\\*\\*\\* (Add File|Update File|Move to): (?<path>.+)$").path)
          | if startswith("/") then . else "\($cwd)/\(.)" end
        ')
        format "''${files[@]}"
        ;;
      --stop)
        root=$(git -C "$(jq -r '.cwd // "."')" rev-parse --show-toplevel 2>/dev/null) || exit 0
        files=()
        while IFS= read -r -d "" entry; do
          # A rename or copy is followed by its source.
          if [[ $entry == [RC]* ]]; then
            IFS= read -r -d "" _
          fi
          if [[ -f $root/''${entry:3} ]]; then
            files+=("$root/''${entry:3}")
          fi
        done < <(git -C "$root" status --porcelain -z --untracked-files=all)
        # Without paths, treefmt would format the whole tree.
        if ((''${#files[@]})); then
          run "$root" "''${files[@]}"
        fi
        ;;
      *)
        format "$@"
        ;;
      esac

      if ((''${#failures[@]})); then
        report=$(printf '%s\n' "''${failures[@]}")
        case $mode in
        --post-tool)
          jq -n --arg context "$report" \
            '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
          ;;
        --stop)
          jq -n --arg message "$report" '{systemMessage: $message}'
          ;;
        *)
          printf '%s\n' "$report" >&2
          exit 1
          ;;
        esac
      fi
    '';
  };

  hooks = matcher: {
    PostToolUse = [
      {
        inherit matcher;
        hooks = [
          {
            type = "command";
            command = "${lib.getExe script} --post-tool";
            timeout = 60;
          }
        ];
      }
    ];
    Stop = [
      {
        hooks = [
          {
            type = "command";
            command = "${lib.getExe script} --stop";
            timeout = 120;
          }
        ];
      }
    ];
  };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  config.programs = {
    claude-code.settings.hooks = hooks "Edit|Write";
    # Codex edits through patches, which `Edit` and `Write` alias.
    codex.hooks = hooks "^apply_patch$";
    # opencode matches the file extension only.
    opencode.settings.formatter.agent-format = {
      command = [
        (lib.getExe script)
        "$FILE"
      ];
      extensions = lib.unique (
        lib.concatMap (language: lib.optionals (language.formatter.tool != null) language.extensions) (
          lib.attrValues languages
        )
      );
    };
  };
}
