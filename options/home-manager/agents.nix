{
  lib,
  ...
}:
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  # Shared agent configuration, read by the module of every agent that can express
  # it. Nothing here writes a file on its own, so an agent whose home-manager module
  # lacks the matching option stays unconfigured until it gains one.
  options.programs.agents = {
    context = lib.mkOption {
      type = with lib.types; either lines path;
      default = "";
      example = lib.literalExpression "./AGENTS.md";
      description = "Shared instructions, either inline or as a markdown file, handed to every agent as its global context.";
    };

    skills = lib.mkOption {
      type = with lib.types; either (attrsOf (either lines path)) path;
      default = { };
      example = lib.literalExpression "./skills";
      description = ''
        Agent Skills (https://agentskills.io/specification), handed to every agent,
        either a directory holding one directory per skill or an attribute set keyed by
        skill name. An attribute is a directory of its own, a single `SKILL.md`, or that
        file's content inline.
      '';
    };

    sandbox = {
      allowedDomains = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        example = [ "*.githubusercontent.com" ];
        description = ''
          Hosts agents may reach, honoured by every agent that sandboxes its network. A
          leading `*.` matches subdomains only, so an apex that is itself contacted has
          to be listed on its own.
        '';
      };

      deniedDomains = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        example = [ "pypi.org" ];
        description = ''
          Hosts agents may not reach, overriding `allowedDomains`. A deny is stronger
          than an omission: an agent that can otherwise ask for an unforeseen host, or
          name one per command, is refused these without a prompt.
        '';
      };

      paths = lib.mkOption {
        type =
          with lib.types;
          attrsOf (enum [
            "read"
            "write"
            "deny"
          ]);
        default = { };
        example = {
          "/nix" = "read";
          "~/.ssh" = "deny";
        };
        description = ''
          Directories outside the workspace and the access agents get to them. An agent
          that confines reads enforces `read` as its allowlist; one that reads freely by
          default only pre-approves its permission prompt with it. `deny` is enforced
          either way and overrides the other two.
        '';
      };

      allowedUnixSockets = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        description = ''
          Unix sockets reachable from a sandbox, given as the path a sandbox sees after
          symlink resolution. Everything absent is a socket an escaped process cannot
          reach, so this list is what keeps agent sockets out of a subprocess' hands.
        '';
      };

      deniedEnvVars = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        example = [ "SSH_AUTH_SOCK" ];
        description = "Variables stripped from the environment agents hand to a subprocess.";
      };

      sessionVariables = lib.mkOption {
        type = with lib.types; attrsOf str;
        default = { };
        description = ''
          Variables set in the environment agents hand to a subprocess. Values are
          strings because that is what every agent writes into a process environment,
          whatever its own config format would allow.
        '';
      };
    };
  };
}
