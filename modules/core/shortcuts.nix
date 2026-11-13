# Web shortcuts, shared by the vicinae launcher and the Homer dashboard of the homelab.
# The option declarations live in options/shared/shortcuts.nix.
#
# Placeholders in a `query` (https://docs.vicinae.com/shortcuts):
# - `{name}` declares an argument that has to be typed in the search bar.
# - `{argument name="channel" default="unstable"}` is the same with a default value.
# - `{clipboard}`, `{selection}`, `{uuid}`, and `{date}` expand on their own.
# A shortcut with exactly one argument doubles as a fallback command in vicinae,
# automatically expanding placeholders do not count towards that.
#
# Icons come from the Font Awesome version that Homer bundles.
# https://fontawesome.com/search?ic=free-collection
let
  shortcuts.custom.shortcuts = {
    # keep-sorted start block=yes
    "cashback-optimizer" = {
      url = "https://cashback-optimizer.de";
      query = "https://cashback-optimizer.de/?filter={query}";
      favicon = "cashback-optimizer.de";
      icon = "fas fa-piggy-bank";
    };
    "claude code changelog" = {
      url = "https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md";
      favicon = "github.com";
      icon = "fab fa-claude";
    };
    "codex changelog" = {
      url = "https://github.com/openai/codex/releases/latest";
      favicon = "github.com";
      icon = "fab fa-openai";
    };
    "ctan" = {
      url = "https://ctan.org";
      query = "https://ctan.org/pkg/{package}";
      favicon = "ctan.org";
      icon = "fas fa-box-archive";
    };
    "dblp" = {
      url = "https://dblp.uni-trier.de";
      query = "https://dblp.uni-trier.de/rec/{clipboard}.html";
      favicon = "dblp.uni-trier.de";
      icon = "fas fa-graduation-cap";
    };
    "dfki calendar" = {
      url = "https://outlook.office.com/calendar/view/workweek";
      favicon = "outlook.office.com";
      icon = "fas fa-calendar-days";
    };
    "docker hub" = {
      url = "https://hub.docker.com";
      query = "https://hub.docker.com/r/{path}";
      favicon = "hub.docker.com";
      icon = "fab fa-docker";
    };
    "doi" = {
      url = "https://doi.org";
      query = "https://doi.org/{clipboard}";
      favicon = "doi.org";
      icon = "fas fa-link";
    };
    "font awesome brand" = {
      url = "https://fontawesome.com/search?ip=brands&ic=free-collection";
      query = "https://fontawesome.com/search?ip=brands&ic=free-collection&q={query}";
      favicon = "fontawesome.com";
      icon = "fab fa-font-awesome";
    };
    "font awesome free" = {
      url = "https://fontawesome.com/search?ic=free-collection&ip=classic&s=solid";
      query = "https://fontawesome.com/search?ic=free-collection&ip=classic&s=solid&q={query}";
      favicon = "fontawesome.com";
      icon = "fab fa-font-awesome";
    };
    "github api" = {
      url = "https://api.github.com";
      query = "https://api.github.com/{path}";
      favicon = "github.com";
      icon = "fab fa-github";
    };
    "github" = {
      url = "https://github.com";
      query = "https://github.com/{path}";
      favicon = "github.com";
      icon = "fab fa-github";
    };
    "google" = {
      url = "https://google.com";
      query = "https://google.com/search?q={query}";
      favicon = "google.com";
      icon = "fab fa-google";
    };
    "home manager docs" = {
      url = "https://nix-community.github.io/home-manager/options.xhtml";
      favicon = "nix-community.github.io";
      icon = "fas fa-snowflake";
    };
    "home manager issues" = {
      url = "https://github.com/nix-community/home-manager/issues";
      query = "https://github.com/nix-community/home-manager/issues?q={query}";
      favicon = "github.com";
      icon = "fab fa-github";
    };
    "home manager search" = {
      url = "https://home-manager-options.extranix.com";
      query = "https://home-manager-options.extranix.com/?query={query}&release={argument name=\"channel\" default=\"master\"}";
      favicon = "home-manager-options.extranix.com";
      icon = "fas fa-snowflake";
    };
    "huggingface" = {
      url = "https://huggingface.co";
      query = "https://huggingface.co/{path}";
      favicon = "huggingface.co";
      icon = "fab fa-hugging-face";
    };
    "idealo" = {
      url = "https://www.idealo.de";
      query = "https://www.idealo.de/preisvergleich/MainSearchProductCategory.html?q={query}";
      favicon = "www.idealo.de";
      icon = "fas fa-tags";
    };
    "kagi assistant" = {
      url = "https://kagi.com/assistant";
      query = "https://kagi.com/assistant?q={query}&profile={argument name=\"model\" default=\"gpt-4o\"}&internet={argument name=\"internet\" default=\"true\"}";
      favicon = "kagi.com";
      icon = "fas fa-robot";
    };
    "kagi" = {
      url = "https://kagi.com";
      query = "https://kagi.com/search?q={query}";
      favicon = "kagi.com";
      icon = "fas fa-magnifying-glass";
    };
    "linguee" = {
      url = "https://www.linguee.com/english-german";
      query = "https://www.linguee.com/english-german/search?source=auto&query={query}";
      favicon = "www.linguee.com";
      icon = "fas fa-language";
    };
    "nix darwin docs" = {
      url = "https://nix-darwin.github.io/nix-darwin/manual/";
      favicon = "nix-darwin.github.io";
      icon = "fas fa-snowflake";
    };
    "nix darwin issues" = {
      url = "https://github.com/nix-darwin/nix-darwin/issues";
      query = "https://github.com/nix-darwin/nix-darwin/issues?q={query}";
      favicon = "github.com";
      icon = "fab fa-github";
    };
    "nix docs" = {
      url = "https://nix.dev/manual/nix/latest/";
      favicon = "nix.dev";
      icon = "fas fa-snowflake";
    };
    "nixos changelog" = {
      url = "https://nixos.org/manual/nixos/unstable/release-notes";
      favicon = "nixos.org";
      icon = "fas fa-snowflake";
    };
    "nixos docs" = {
      url = "https://nixos.org/manual/nixos/unstable/";
      favicon = "nixos.org";
      icon = "fas fa-snowflake";
    };
    "nixos search" = {
      url = "https://search.nixos.org/options";
      query = "https://search.nixos.org/options?query={query}&channel={argument name=\"channel\" default=\"unstable\"}";
      favicon = "search.nixos.org";
      icon = "fas fa-snowflake";
    };
    "nixpkgs docs" = {
      url = "https://nixos.org/manual/nixpkgs/unstable/";
      favicon = "nixos.org";
      icon = "fas fa-snowflake";
    };
    "nixpkgs issues" = {
      url = "https://github.com/nixos/nixpkgs/issues";
      query = "https://github.com/nixos/nixpkgs/issues?q={query}";
      favicon = "github.com";
      icon = "fab fa-github";
    };
    "nixpkgs search" = {
      url = "https://search.nixos.org/packages";
      query = "https://search.nixos.org/packages?query={query}&channel={argument name=\"channel\" default=\"unstable\"}";
      favicon = "search.nixos.org";
      icon = "fas fa-snowflake";
    };
    "nixpkgs tracker" = {
      url = "https://nixpkgs-tracker.ocfox.me";
      query = "https://nixpkgs-tracker.ocfox.me/?pr={clipboard}";
      favicon = "nixpkgs-tracker.ocfox.me";
      icon = "fas fa-code-pull-request";
    };
    "nixvim docs" = {
      url = "https://nix-community.github.io/nixvim/";
      favicon = "nix-community.github.io";
      icon = "fab fa-vim";
    };
    "nixvim issues" = {
      url = "https://github.com/nix-community/nixvim/issues";
      query = "https://github.com/nix-community/nixvim/issues?q={query}";
      favicon = "github.com";
      icon = "fab fa-github";
    };
    "noogle" = {
      url = "https://noogle.dev";
      query = "https://noogle.dev/q?term={query}";
      favicon = "noogle.dev";
      icon = "fas fa-snowflake";
    };
    "npm" = {
      url = "https://www.npmjs.com";
      query = "https://www.npmjs.com/package/{package}";
      favicon = "www.npmjs.com";
      icon = "fab fa-npm";
    };
    "npmx" = {
      url = "https://www.npmx.dev";
      query = "https://www.npmx.dev/package/{package}";
      favicon = "www.npmx.dev";
      icon = "fab fa-npm";
    };
    "pypi" = {
      url = "https://pypi.org";
      query = "https://pypi.org/project/{package}";
      favicon = "pypi.org";
      icon = "fab fa-python";
    };
    "searchix" = {
      url = "https://searchix.alanpearce.eu";
      query = "https://searchix.alanpearce.eu/{argument name=\"scope\" default=\"all\"}/search?query={query}";
      icon = "fas fa-snowflake";
    };
    "typst universe" = {
      url = "https://typst.app/universe";
      query = "https://typst.app/universe/package/{package}/";
      favicon = "typst.app";
      icon = "fas fa-box-open";
    };
    "x" = {
      url = "https://x.com";
      query = "https://twitter.com/i/web/status/{clipboard}";
      favicon = "twitter.com";
      icon = "fab fa-x-twitter";
    };
    # keep-sorted end
  };
in
{
  flake.modules.nixos.base = shortcuts;
  flake.modules.homeManager.default = shortcuts;
}
