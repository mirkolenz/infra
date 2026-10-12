# `programs.codex.requirements` for nix-darwin and NixOS, which both read `/etc/codex`.
# https://developers.openai.com/codex/security#admin-enforced-requirements
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.codex;
  tomlFormat = pkgs.formats.toml { };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.codex.requirements = lib.mkOption {
    inherit (tomlFormat) type;
    default = { };
    example.allow_managed_hooks_only = true;
    description = ''
      Requirements that Codex enforces on every other config layer, for the CLI and the
      desktop app alike. They live outside of the home directory, out of reach of users and agents.
    '';
  };

  config.environment.etc."codex/requirements.toml" = lib.mkIf (cfg.requirements != { }) {
    source = tomlFormat.generate "codex-requirements.toml" cfg.requirements;
  };
}
