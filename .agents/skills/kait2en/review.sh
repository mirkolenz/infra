#!/usr/bin/env bash
# Review helper for the kait2en skill, run from anywhere in the repository.
#   upstream  commits and files upstream changed from `reviewedSrc` to `src`
#   fork      commits and Nix layer files the NixOS fork changed since `reviewedFork`
#   advance   moves `reviewedSrc` to `src` and `reviewedFork` to the fork's main
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

check=pkgs/by-name/kait2en/upstream-check.nix
fork=LukeChannings/KaiT2en-NixOS

# One evaluation for every pin, read into plain variables so a failure aborts.
# shellcheck disable=SC2016 # Nix interpolation, not shell
pins=$(nix eval --json .#packages.x86_64-linux.kait2en-upstream-check --apply 'c: {
  upstream = "${c.src.owner}/${c.src.repo}";
  inherit (c) reviewedFork;
  reviewedRev = c.reviewedSrc.rev;
  reviewedHash = c.reviewedSrc.outputHash;
  rev = c.src.rev;
  hash = c.src.outputHash;
}')
pin() {
  jq -er ".$1" <<<"$pins"
}
upstream=$(pin upstream)
reviewedFork=$(pin reviewedFork)
reviewedRev=$(pin reviewedRev)
reviewedHash=$(pin reviewedHash)
rev=$(pin rev)
hash=$(pin hash)

# Prints the commits of a range and its files matching a regex.
compare() {
  gh api "repos/$1/compare/$2...$3" --jq "
    (.commits[] | .sha[0:8] + \" \" + (.commit.message | split(\"\n\")[0])),
    \"\",
    (.files[] | select(.filename | test(\"$4\")) | \"\(.status)\t\(.filename)\")
  "
}

case "${1:-}" in
upstream)
  compare "$upstream" "$reviewedRev" "$rev" .
  ;;
fork)
  # Only its Nix layer, the rest mirrors upstream.
  compare "$fork" "$reviewedFork" main '^(nix/|patches/nixos/|flake\\.nix$|.*package\\.nix$|\\.agents/)'
  ;;
advance)
  forkHead=$(gh api "repos/$fork/commits/main" --jq .sha)
  sed -i \
    -e "s|$reviewedRev|$rev|" \
    -e "s|$reviewedHash|$hash|" \
    -e "s|$reviewedFork|$forkHead|" \
    "$check"
  git diff --stat -- "$check"
  ;;
*)
  echo "usage: $0 upstream|fork|advance" >&2
  exit 1
  ;;
esac
