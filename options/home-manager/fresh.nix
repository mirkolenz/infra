# Maps the shared languages of options/shared/_editors onto Fresh. Each server runs
# from its Nix package, and Fresh starts no others, so it never downloads one on its own.
# It formats on save through the formatting server of a language, or else its formatter,
# and skips the fixers, since its on-save commands cannot change the buffer.
{ config, lib, ... }:
let
  inherit (config.custom) editors languages tools;

  # Fresh sends the identifier of its language, so a language that it files under another
  # one keeps its own through the extensions of its files.
  languageIds =
    id:
    let
      language = languages.${id};
      shared = lib.any (name: name != id && languages ? ${name}) language.editors.fresh.names;
    in
    lib.optionalAttrs shared (lib.genAttrs (map (lib.removePrefix ".") language.extensions) (_: id));

  # Fresh answers the workspace configuration from the initialization options.
  mkServer =
    name: server:
    let
      initializationOptions = lib.recursiveUpdate server.initializationOptions server.settings;
      languageIdOverrides = lib.mergeAttrsList (map languageIds server.languages);
    in
    {
      inherit name;
      inherit (server) command args;
      auto_start = true;
    }
    // lib.optionalAttrs (initializationOptions != { }) {
      initialization_options = initializationOptions;
    }
    // lib.optionalAttrs (languageIdOverrides != { }) {
      language_id_overrides = languageIdOverrides;
    }
    // (
      if server.linter then
        {
          only_features = [
            "diagnostics"
            "code_action"
          ]
          ++ lib.optional server.formats "format";
        }
      else
        lib.optionalAttrs (!server.formats) { except_features = [ "format" ]; }
    );

  servers = lib.mapAttrs mkServer config.custom.active.servers;

  mkLanguage =
    { formatter, ... }:
    let
      tool = tools.${formatter.tool};
    in
    if formatter.server != null then
      { format_on_save = true; }
    else
      lib.optionalAttrs (formatter.tool != null && tool.stdinArgs != null) {
        format_on_save = true;
        formatter = {
          inherit (tool) command;
          args = tool.stdinArgsWith "$FILE";
          stdin = true;
        };
      };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  imports = [ ../shared/_editors ];

  # A single server of a language merges with the built-in one, keeping its root
  # markers, while several replace it and take the working directory as their root.
  config.programs.fresh-editor.settings = lib.mkIf config.programs.fresh-editor.enable {
    lsp = lib.mapAttrs (_: language: lib.attrVals language.servers servers) (
      lib.filterAttrs (_: language: language.servers != [ ]) editors.fresh
    );
    universal_lsp = lib.getAttrs config.custom.universal.servers servers;
    languages = lib.filterAttrs (_: language: language != { }) (
      lib.mapAttrs (_: mkLanguage) editors.fresh
    );
  };
}
