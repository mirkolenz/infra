{
  flake.modules.homeManager.default =
    { config, lib, ... }@args:
    let
      opnix = args.osConfig.services.onepassword-secrets or { enable = false; };
    in
    lib.mkIf config.programs.agents.enable {
      programs.agents.sandbox = lib.mkIf opnix.enable {
        # the opnix service account token, which reads the whole vault, and the access tokens of nix
        paths.deny = [
          opnix.tokenFile
          opnix.secretPaths.nixAccessTokens
        ];
        # nix fetches in the client, which applies the `access-tokens` of `NIX_CONFIG`.
        environment.files = {
          GH_TOKEN = opnix.secretPaths.agentsGithubToken;
          NIX_CONFIG = opnix.secretPaths.nixAccessTokens;
        };
      };
      # Only nono strips the host tokens, the native sandboxes of the harnesses would drop the injected ones.
      programs.nono.profiles.agents.environment.deny_vars = [
        "GH_TOKEN"
        "GITHUB_TOKEN"
        "NIX_CONFIG"
      ];
    };
}
