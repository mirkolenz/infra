{
  flake.modules.homeManager.default =
    {
      lib,
      lib',
      config,
      pkgs,
      ...
    }@args:
    let
      llamaCpp = args.osConfig.services.llama-cpp or { enable = false; };
      agents = config.programs.agents;
      sandbox = lib'.splitSandbox agents.sandbox;

      # `*` also matches `/`
      withContent = lib'.withContent "*";

      # a trailing ` *` matches the bare command as well
      commandPatterns = map (cmd: "${cmd} *");

      mkRules =
        effect: action:
        map (resource: {
          inherit action resource effect;
        });

      # resources are `<action>:<value>`
      denyRules = action: map (resource: "${action}:${resource}");

      # the private servers of the sessions within nono
      serverPorts = [
        18100
        18199
      ];

      # A private server runs inside nono, since the background service would not.
      # `--standalone` serves on a random port as of opencode 2.0.27, which nono keeps closed.
      launcher = pkgs.writeShellApplication {
        name = "opencode";
        text = /* bash */ ''
          opencode=${lib.getExe config.programs.opencode.package}

          # nono sets NONO_CAP_FILE in every sandbox it starts.
          if [[ ! -f ''${NONO_CAP_FILE:-} ]]; then
            exec "$opencode" "$@"
          fi

          # the first port nothing listens on
          for port in {${lib.concatMapStringsSep ".." toString serverPorts}}; do
            if ! true 2>/dev/null <"/dev/tcp/127.0.0.1/$port"; then
              break
            fi
          done

          printf -v OPENCODE_PASSWORD '%08x' "$SRANDOM" "$SRANDOM" "$SRANDOM" "$SRANDOM"
          export OPENCODE_PASSWORD
          # With `--stdio`, the server reports its readiness and stops once this script exits.
          coproc server { "$opencode" serve --stdio --hostname 127.0.0.1 --port "$port" 2>/dev/null; }

          if ! read -r _ <&"''${server[0]}"; then
            echo "opencode: the server failed to start on port $port" >&2
            exit 1
          fi

          "$opencode" --server "http://127.0.0.1:$port" "$@"
        '';
      };
    in
    lib.mkIf config.programs.agents.enable {
      programs.opencode = {
        enable = true;
        package = pkgs.opencode-bin;
        inherit (agents) context skills;
        # https://opencode.ai/v2/docs/config
        settings = {
          share = "disabled";
          update = "disable";
          model = lib.mkIf llamaCpp.enable "llama-cpp/qwen3.6-35b-a3b";
          providers.llama-cpp = lib.mkIf llamaCpp.enable {
            name = "llama.cpp";
            package = "@opencode/ai/providers/openai-compatible";
            settings.baseURL = "http://127.0.0.1:${toString llamaCpp.settings.port}/v1";
            models."qwen3.6-35b-a3b".name = "Qwen 3.6 MoE";
          };
          # home-manager's `enableMcpIntegration` still renders the V1 shape
          mcp.servers = lib.mapAttrs (_: server: {
            type = "local";
            command = [ server.command ] ++ server.args or [ ];
          }) config.programs.mcp.servers;
          # https://opencode.ai/v2/docs/permissions
          # upstream allows the workspace and asks for anything outside it
          permissions =
            mkRules "allow" "external_directory" (withContent (sandbox.readPaths ++ sandbox.writePaths))
            ++ mkRules "allow" "shell" (commandPatterns sandbox.allowedCommands);
          # https://opencode.ai/v2/docs/policies
          # hard denies that neither an "Allow always" approval nor a project config lifts
          experimental.policies =
            mkRules "deny" "provider.use" [ "*" ]
            # the openai credential comes from `/connect`
            ++ mkRules "allow" "provider.use" [
              "llama-cpp"
              "openai"
            ]
            ++ mkRules "deny" "tool.use" (
              # `*:` covers every path-based action
              denyRules "*" (withContent sandbox.deniedPaths)
              ++ denyRules "edit" (withContent sandbox.readPaths)
              ++ denyRules "shell" (commandPatterns sandbox.deniedCommands)
            );
        };
      };
      programs.agents = {
        harnesses.opencode = {
          launchers.opencode = launcher;
          # the `/connect` logins are kept in the database below `dataHome`
          stateDirs = [
            "${config.xdg.configHome}/opencode"
            "${config.xdg.dataHome}/opencode"
            "${config.xdg.dataHome}/opentui"
            "${config.xdg.stateHome}/opencode"
            "${config.home.homeDirectory}/.opencode"
          ];
          # every plugin runs outside of nono as well
          protectedEntries = [
            "AGENTS.md"
            "opencode.json"
            "plugins"
            "skills"
          ];
          domains = [
            "api.openai.com"
            "auth.openai.com"
            "chatgpt.com"
            "models.opencode.ai"
          ];
        };
        # The project config, every plugin there runs outside of nono as well, except for the prompts.
        sandbox.paths = {
          ".opencode" = "read";
          # singular and plural names
          ".opencode/agent*" = "write";
          ".opencode/command*" = "write";
          ".opencode/mode*" = "write";
          ".opencode/skill*" = "write";
          "opencode.json*" = "read";
        };
      };
      # llama.cpp and the private servers, loopback is already in `NO_PROXY`.
      # The profile is shared, since a nested session keeps the ports of the outer one.
      programs.nono.profiles.agents.network = {
        open_port = lib.optional llamaCpp.enable llamaCpp.settings.port;
        open_port_range = [ serverPorts ];
      };
    };
}
