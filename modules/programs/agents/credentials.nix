{
  flake.modules.homeManager.default =
    { config, lib, ... }@args:
    let
      opnix = args.osConfig.services.onepassword-secrets or { enable = false; };
    in
    lib.mkIf config.programs.agents.enable {
      programs.agents.sandbox = lib.mkIf opnix.enable {
        # Also cover secrets rendered outside outputDir and future ones added there.
        paths.deny = lib.unique (
          [
            opnix.tokenFile
            opnix.outputDir
          ]
          ++ lib.attrValues opnix.secretPaths
        );
        environment.files.GITHUB_TOKEN = opnix.secretPaths.agentsGithubToken;
      };
    };
}
