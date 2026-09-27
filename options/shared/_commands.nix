# `custom.commands` for home-manager, nix-darwin and NixOS, which only differ in
# the option at `packagesPath` that receives the packaged scripts.
# A command is a bash script whose argc comment tags declare its interface,
# which argc compiles together with its help, man pages and shell completions.
# https://github.com/sigoden/argc/blob/main/docs/specification.md
packagesPath:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  eval = ''eval "$(argc --argc-eval "$0" "$@")"'';

  # `pkgs.writeShellApplication`, whose checks run on the script compiled by argc,
  # since only that one assigns the variables of the parameters.
  argcBuilder =
    command:
    let
      inherit (command) name;
      derivationArgs = command.derivationArgs or { };
    in
    pkgs.writeShellApplication (
      removeAttrs command [ "builder" ]
      // {
        text = ''
          ${eval}
          ${command.text}
        '';
        # Without nounset, since argc leaves the variables of absent parameters unset,
        # while ShellCheck still reports misspelled ones as never assigned.
        bashOptions =
          command.bashOptions or [
            "errexit"
            "pipefail"
          ];
        # The parser leaves variables unread and quotes its messages in single quotes.
        excludeShellChecks = [
          "SC2016"
          "SC2034"
        ]
        ++ command.excludeShellChecks or [ ];
        derivationArgs = derivationArgs // {
          nativeBuildInputs = [
            pkgs.argc
            pkgs.installShellFiles
            pkgs.jq
          ]
          ++ derivationArgs.nativeBuildInputs or [ ];
          # Compiles the script that the checks then run on, from a copy of its source named after
          # the command, since argc names the help after the file and only parses tags ahead of its parser.
          # argc calls `main` or the subcommand at its eval, which therefore has to follow their definitions.
          preCheck = ''
            if argc --argc-export "$target" | jq --exit-status '.command_fn != null or .subcommands != []' >/dev/null; then
              { grep --invert-match --line-regexp --fixed-strings ${lib.escapeShellArg eval} "$target"; echo ${lib.escapeShellArg eval}; } > ${name}
            else
              cp "$target" ${name}
            fi
            argc --argc-build ${name} "$target"
          ''
          + derivationArgs.preCheck or "";
          # Installs the man pages and completions once the checks passed.
          # The completions call argc at runtime to parse the tags of the installed command,
          # and zsh autoloads its file as the completion function, which has to define the completer first.
          postCheck = ''
            argc --argc-mangen ${name} man
            installManPage man/*
            for shell in bash fish zsh; do
              argc --argc-completions "$shell" ${name} > "completion.$shell"
              substituteInPlace "completion.$shell" \
                --replace-fail "argc --argc-compgen" "${lib.getExe pkgs.argc} --argc-compgen"
            done
            { echo '#compdef ${name}'; cat completion.zsh; echo '_argc_completer "$@"'; } > _${name}
            installShellCompletion --cmd ${name} --bash completion.bash --fish completion.fish --zsh _${name}
          ''
          + derivationArgs.postCheck or "";
        };
      }
    );

  command = types.submodule (
    { name, ... }:
    {
      # Further arguments of `pkgs.writeShellApplication`, such as `runtimeInputs`.
      freeformType = with types; attrsOf anything;

      options = {
        name = mkOption {
          type = types.strMatching "[a-zA-Z0-9][a-zA-Z0-9._-]*";
          default = name;
          defaultText = lib.literalMD "the attribute name";
          description = "Name of the script, which may differ from the attribute name.";
        };

        text = mkOption {
          type = types.lines;
          description = ''
            Bash script whose argc comment tags declare its interface,
            with the parameters set as `argc_<name>` variables.
            It runs from top to bottom, unless it defines `main` or subcommand functions,
            which argc calls instead.
            A blank line has to separate the tags from comments of the body,
            which argc would otherwise add to the description of the last tag.
          '';
        };

        builder = mkOption {
          type = types.functionTo types.package;
          default = argcBuilder;
          defaultText = lib.literalMD "argc";
          example = lib.literalExpression ''
            { name, text, ... }:
            pkgs.writers.writePython3Bin name { libraries = [ pkgs.python3Packages.httpx ]; } text
          '';
          description = "Function of the command that packages it, which has to handle all of its attributes.";
        };
      };
    }
  );
in
{
  options.custom.commands = lib.mkOption {
    # Lazy, so that commands can refer to each other without infinite recursion.
    type = types.lazyAttrsOf command;
    default = { };
    apply = lib.mapAttrs (_: command: command.builder command);
    example = lib.literalExpression ''
      {
        greet = {
          runtimeInputs = [ pkgs.cowsay ];
          text = '''
            # @describe Print a greeting
            # @arg name!                    Person to greet
            # @option -g --greeting=Hello

            cowsay "$argc_greeting $argc_name"
          ''';
        };
      }
    '';
    description = ''
      Commands installed into the environment, which argc compiles from their bash `text`
      together with their help, man pages and shell completions.
      Reading the option yields the packages, so commands can refer to each other
      via `config.custom.commands.<name>`.
    '';
  };

  config = lib.setAttrByPath packagesPath (lib.attrValues config.custom.commands);
}
