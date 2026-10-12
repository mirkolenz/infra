{
  flake.modules.homeManager.default =
    { config, lib, ... }@args:
    let
      opnix = args.osConfig.services.onepassword-secrets or { enable = false; };
    in
    lib.mkIf config.programs.agents.enable {
      # the opnix service account token, which reads the whole vault, and the access tokens of nix
      programs.agents.sandbox.paths.deny = lib.mkIf opnix.enable [
        opnix.tokenFile
        opnix.secretPaths.nixAccessTokens
      ];
      # nono strips the host tokens and injects the read-only ones from opnix, aborting while a file is missing.
      # nix fetches in the client, which applies the `access-tokens` of `NIX_CONFIG`.
      programs.nono.profiles.agents = {
        environment.deny_vars = [
          "GH_TOKEN"
          "GITHUB_TOKEN"
          "NIX_CONFIG"
        ];
        env_credentials = lib.mkIf opnix.enable {
          "file://${opnix.secretPaths.agentsGithubToken}" = "GH_TOKEN";
          "file://${opnix.secretPaths.nixAccessTokens}" = "NIX_CONFIG";
        };
      };
    };
}
