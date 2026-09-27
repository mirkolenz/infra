{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      mkNodeApp = name: values: {
        text = /* bash */ ''
          # @describe Run ${name} with npx
          # @arg args~ Arguments of ${name}

          exec ${lib.getExe' pkgs.nodejs "npx"} \
            ${toString (map (v: "--package ${v}") values)} \
            ${name} "$@"
        '';
      };
      mkPythonApp = name: values: {
        text = /* bash */ ''
          # @describe Run ${name} with uvx
          # @arg args~ Arguments of ${name}

          exec ${lib.getExe' config.programs.uv.package "uvx"} \
            --python ${lib.getExe pkgs.python3} \
            ${toString (map (v: "--from ${v}") values)} \
            ${name} "$@"
        '';
      };
    in
    lib.mkIf config.custom.features.extras.enable {
      custom.commands =
        (lib.mapAttrs mkNodeApp {
          gemini = [ "@google/gemini-cli" ];
          icloud-photos-sync = [ "icloud-photos-sync" ];
          mcp-inspector = [ "@modelcontextprotocol/inspector" ];
          shadcn = [ "shadcn" ];
          ccusage = [ "ccusage" ];
          cyclonedx-npm = [ "@cyclonedx/cyclonedx-npm" ];
        })
        // (lib.mapAttrs mkPythonApp {
          arguebuf = [ "arguebuf[cli]" ];
          ast-grep-server = [ "git+https://github.com/ast-grep/ast-grep-mcp" ];
        });
    };
}
