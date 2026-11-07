{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      gh = lib.getExe config.programs.gh.package;
      jq = lib.getExe config.programs.jq.package;
      extras = config.custom.features.extras.enable;
    in
    {
      home.packages = [ pkgs.gh-actions-lock-bin ] ++ lib.optionals extras [ pkgs.glab ];
      programs.gh = {
        enable = true;
        extensions = [ pkgs.gh-actions-lock-bin ];
        settings = {
          git_protocol = "ssh";
        };
      };
      programs.gh-dash = {
        enable = lib.mkDefault extras;
      };
      custom.commands.gh-prs.text = /* bash */ ''
        # @describe Merge the open pull requests that match the given qualifiers and jq condition
        #
        # Example: gh-prs --repo mirkolenz/infra --author app/renovate
        # @option -m --method[squash|merge|rebase]  Merge method, asked for if absent
        # @option -a --author                       Author of the pull requests, such as app/renovate
        # @option -A --assignee                     Assignee of the pull requests, defaulting to @me without other qualifiers
        # @option -r --repo*                        Repository of the pull requests in owner/name format
        # @option -o --owner*                       Owner of the repositories
        # @option -f --filter=true                  jq condition on the title, url, number and repository of a pull request
        # @arg gh-args~                             Further arguments of gh search prs

        if [ -z "$argc_author$argc_assignee''${argc_repo[*]}''${argc_owner[*]}" ]; then
          argc_assignee="@me"
        fi

        matched="$(${gh} search prs --state open \
          ''${argc_author:+"--author=$argc_author"} \
          ''${argc_assignee:+"--assignee=$argc_assignee"} \
          "''${argc_repo[@]/#/--repo=}" \
          "''${argc_owner[@]/#/--owner=}" \
          "''${argc_gh_args[@]}" \
          --json title,url,number,repository --jq "[.[] | select($argc_filter)]")"

        if [ "$matched" = "[]" ]; then
          echo "No matching pull requests found."
          exit 0
        fi

        echo "Matching pull requests:"
        echo
        ${jq} -r '
          ["REPOSITORY", "ID", "TITLE"],
          (.[] | [.repository.nameWithOwner, "#\(.number)", .title])
          | @tsv
        ' <<<"$matched" | column -t -s $'\t'
        echo

        if [ -z "$argc_method" ]; then
          read -r -n 1 -p "How should they be merged? (s)quash/(m)erge/(r)ebase, any other key to skip " key
          echo

          case "$key" in
            s) argc_method="squash" ;;
            m) argc_method="merge" ;;
            r) argc_method="rebase" ;;
            *) echo "Nothing merged."; exit 0 ;;
          esac
        fi

        ${jq} -r '.[].url' <<<"$matched" |
          xargs -P 8 -I {} ${gh} pr merge {} "--$argc_method" --delete-branch --auto
      '';
    };
}
