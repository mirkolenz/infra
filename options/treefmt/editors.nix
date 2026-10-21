# Maps the shared languages of options/shared/_editors onto the formatters of treefmt-nix, which
# change the files in place. The universal fixers run first, then the fixers of a language in
# their order, then its formatter.
{ config, lib, ... }:
let
  inherit (config.custom) active universal;

  languages = lib.attrValues active.languages;

  # The latest position of a tool in the sequence of a language.
  priorities = lib.zipAttrsWith (_: lib.foldl' lib.max 0) (
    lib.concatMap (language: lib.imap0 (index: name: { ${name} = index; }) language.tools) languages
  );

  # treefmt matches the paths relative to the tree root, where `*` also crosses directories.
  glob =
    pattern:
    if lib.hasPrefix "*" pattern || lib.hasInfix "/" pattern then
      [ pattern ]
    else
      [
        pattern
        "*/${pattern}"
      ];
  includes =
    name:
    if lib.elem name universal.fixers then
      [ "*" ]
    else
      lib.unique (
        lib.concatMap (
          language: lib.optionals (lib.elem name language.tools) (lib.concatMap glob language.files)
        ) languages
      );
in
{
  imports = [ ../shared/_editors ];

  settings.formatter = lib.mapAttrs (
    name: tool:
    {
      inherit (tool) command;
      options = tool.args;
      includes = includes name;
      priority = priorities.${name};
    }
    // lib.optionalAttrs (tool.stdinArgs != null) { stdin-options = tool.stdinArgsWith "$path"; }
  ) active.tools;
}
