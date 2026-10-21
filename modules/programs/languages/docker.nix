{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages = {
          dockercompose = {
            files = [
              "compose.yaml"
              "compose.yml"
              "docker-compose.yaml"
              "docker-compose.yml"
            ];
            editors = {
              neovim.names = [ "yaml.docker-compose" ];
              zed = {
                names = [ "Docker Compose" ];
                extensions = [ "docker-compose" ];
              };
            };
            servers = [
              "docker_language_server"
              "yamlls"
            ];
            formatter.server = "docker_language_server";
          };
          dockerfile = {
            files = [
              "Containerfile"
              "Dockerfile"
              "*.dockerfile"
            ];
            editors.zed = {
              names = [ "Dockerfile" ];
              extensions = [ "dockerfile" ];
            };
            servers = [ "docker_language_server" ];
            formatter.server = "docker_language_server";
          };
        };

        lsp.servers.docker_language_server = {
          package = pkgs.docker-language-server;
          args = [
            "start"
            "--stdio"
          ];
          editors.zed.name = "docker-language-server";
        };
      };
    };
}
