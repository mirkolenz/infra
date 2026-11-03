# Fails until every package builds from the upstream revision last reviewed.
# `outdated` replays each sparse checkout on the reviewed tree with git itself,
# so its patterns mean exactly what they mean to the fetcher.
{
  lib,
  fetchFromGitHub,
  git,
  runCommand,
  kait2en,
}:
let
  # The revisions last reviewed, written only by `review.py advance`.
  reviewed = lib.importJSON ./reviewed.json;

  # Every scope attribute fetched through `fetchSource`.
  packages = lib.filterAttrs (_: package: package.src.sparseCheckout or null != null) (
    lib.removeAttrs kait2en [ "upstream-check" ]
  );

  reviewedSrc = fetchFromGitHub {
    owner = "kaiT2en";
    repo = "KaiT2en-Fedora";
    inherit (reviewed.upstream) rev hash;
  };

  # The names of the packages whose files differ there, which `review.py
  # update` runs nix-update for.
  outdated = runCommand "kait2en-upstream-outdated" { nativeBuildInputs = [ git ]; } ''
    cp -r --no-preserve=mode ${reviewedSrc} reviewed
    cd reviewed
    git init --quiet
    git add --all
    git -c user.name=check -c user.email=check commit --quiet --message reviewed
    touch $out

    ${lib.concatMapAttrsStringSep "\n" (name: package: ''
      git sparse-checkout set --no-cone ${lib.escapeShellArgs package.src.sparseCheckout}
      diff -rq --no-dereference --exclude=.git . ${package.src} > /dev/null || echo ${name} >> $out
    '') packages}
  '';
in
runCommand "kait2en-upstream-check"
  {
    passthru = { inherit reviewedSrc outdated; };
    meta = {
      description = "Check that every KaiT2en package builds from the reviewed upstream revision";
      platforms = lib.platforms.unix;
      # the diff is the same on every system, so CI runs it once
      hydraPlatforms = [ "x86_64-linux" ];
    };
  }
  ''
    if [ -s ${outdated} ]; then
      echo "Not built from the reviewed revision, see .agents/skills/kait2en/SKILL.md:" >&2
      cat ${outdated} >&2
      exit 1
    fi

    touch $out
  ''
