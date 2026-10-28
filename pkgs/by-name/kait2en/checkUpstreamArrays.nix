# Diffs each list against the array an upstream script has built once its
# top-level assignments ran, so a bump fails loudly instead of silently.
# shfmt parses those assignments out, so nothing else in the script runs.
{
  lib,
  jq,
  shfmt,
}:
mirrored: ''
  upstreamArray() {
    local assignments
    assignments=$(${lib.getExe shfmt} --to-json <"$1" |
      ${lib.getExe jq} '.Stmts |= map(select(.Cmd.Type == "CallExpr" and .Cmd.Args == null))' |
      ${lib.getExe shfmt} --from-json)

    (
      # Some call helpers from the unsourced `lib.sh`, which only leaves
      # those variables empty.
      eval "$assignments" || true
      local -n array=$2
      printf '%s\n' "''${array[@]}"
    ) | sort
  }

  ${lib.concatMapStringsSep "\n" (
    {
      file,
      array,
      values,
    }:
    ''
      diff -u <(upstreamArray ${file} ${array}) \
        <(printf '%s\n' ${lib.escapeShellArgs values} | sort) ||
        { echo "${array} in ${file} changed upstream, see .agents/skills/kait2en/SKILL.md" >&2; exit 1; }
    ''
  ) mirrored}
''
