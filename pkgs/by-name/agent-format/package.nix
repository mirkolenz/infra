{
  lib,
  mkPythonApp,
  gitMinimal,
  treefmt-nix,
}:
let
  treefmt = treefmt-nix.config;

  # the languages with a formatter of their own, which run on each edit
  languages = lib.filter (language: language.formatter.tool != null) (
    lib.attrValues treefmt.custom.active.languages
  );
in
mkPythonApp {
  script = "agent-format";
  description = "Format the files that coding agents edit with treefmt";
  # run by the agents and their harnesses, not by people
  interactive = false;
  runtimeInputs = [
    gitMinimal
    treefmt.package
  ];
  flags = {
    config-file = treefmt.build.configFile;
    formatters = lib.concatStringsSep "," (
      lib.unique (map (language: language.formatter.tool) languages)
    );
  };
  # the file extensions of the formatted languages, for harnesses that match by extension
  passthru.extensions = lib.unique (lib.concatMap (language: language.extensions) languages);
}
