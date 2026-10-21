let
  # The JavaScript and TypeScript languages.
  scripts = {
    servers = [
      "tsc"
      "oxlint"
      "tailwindcss"
    ];
    fixers = [ "oxlint" ];
    formatter.tool = "oxfmt";
  };

in
{
  flake.modules.generic.languages =
    { lib, pkgs, ... }:
    let
      # The Volar based servers load TypeScript from here, which only ships its JavaScript API
      # up to version 5. Without it, the editors would look for one in node_modules or download it.
      tsdk = "${pkgs.typescript_5}/lib/node_modules/typescript/lib";

      # The servers extracted from Visual Studio Code, which share one package without a main program.
      vscodeServer =
        {
          name,
          zedName ? "vscode-${name}-language-server",
        }:
        {
          package = pkgs.vscode-langservers-extracted;
          command = lib.getExe' pkgs.vscode-langservers-extracted "vscode-${name}-language-server";
          args = [ "--stdio" ];
          editors.zed.name = zedName;
        };
    in
    {
      custom = {
        languages = {
          # keep-sorted start block=yes
          astro = {
            files = [ "*.astro" ];
            editors.zed = {
              names = [ "Astro" ];
              extensions = [ "astro" ];
            };
            servers = [
              "astro"
              "oxlint"
              "tailwindcss"
            ];
            fixers = [ "oxlint" ];
            formatter.server = "astro";
          };
          css = {
            files = [ "*.css" ];
            editors.zed.names = [ "CSS" ];
            servers = [
              "cssls"
              "tailwindcss"
            ];
            formatter.tool = "oxfmt";
          };
          graphql = {
            files = [
              "*.graphql"
              "*.gql"
            ];
            formatter.tool = "oxfmt";
          };
          handlebars = {
            files = [
              "*.handlebars"
              "*.hbs"
            ];
            formatter.tool = "oxfmt";
          };
          html = {
            files = [
              "*.htm"
              "*.html"
            ];
            editors.zed = {
              names = [ "HTML" ];
              extensions = [ "html" ];
            };
            servers = [
              "html"
              "tailwindcss"
            ];
            formatter.tool = "oxfmt";
          };
          javascript = {
            imports = [ scripts ];
            files = [
              "*.cjs"
              "*.js"
              "*.mjs"
            ];
            editors.zed.names = [ "JavaScript" ];
          };
          javascriptreact = {
            imports = [ scripts ];
            files = [ "*.jsx" ];
            editors = {
              zed.names = [ "JavaScript" ];
              fresh.names = [ "javascript" ];
            };
          };
          json = {
            files = [ "*.json" ];
            editors.zed.names = [ "JSON" ];
            servers = [ "jsonls" ];
            formatter.tool = "oxfmt";
          };
          json5 = {
            files = [ "*.json5" ];
            formatter.tool = "oxfmt";
          };
          jsonc = {
            files = [ "*.jsonc" ];
            editors.zed.names = [ "JSONC" ];
            servers = [ "jsonls" ];
            formatter.tool = "oxfmt";
          };
          less = {
            files = [ "*.less" ];
            servers = [ "cssls" ];
            formatter.tool = "oxfmt";
          };
          mdx = {
            files = [ "*.mdx" ];
            editors = {
              # see modules/nixvim/filetype.nix
              neovim.names = [ "markdown.mdx" ];
              zed = {
                names = [ "MDX" ];
                extensions = [ "mdx" ];
              };
            };
            servers = [ "mdx_analyzer" ];
            formatter.tool = "oxfmt";
          };
          scss = {
            files = [ "*.scss" ];
            servers = [ "cssls" ];
            formatter.tool = "oxfmt";
          };
          typescript = {
            imports = [ scripts ];
            files = [
              "*.cts"
              "*.mts"
              "*.ts"
            ];
            editors.zed.names = [ "TypeScript" ];
          };
          typescriptreact = {
            imports = [ scripts ];
            files = [ "*.tsx" ];
            editors = {
              zed.names = [ "TSX" ];
              fresh.names = [ "typescript" ];
            };
          };
          vue = {
            files = [ "*.vue" ];
            fixers = [ "oxlint" ];
            formatter.tool = "oxfmt";
          };
          # keep-sorted end
        };

        lsp.servers = {
          # keep-sorted start block=yes
          astro = {
            package = pkgs.astro-language-server;
            args = [ "--stdio" ];
            initializationOptions.typescript.tsdk = tsdk;
            editors.zed.name = "astro-language-server";
          };
          cssls = vscodeServer { name = "css"; };
          html = vscodeServer { name = "html"; };
          jsonls = vscodeServer {
            name = "json";
            zedName = "json-language-server";
          };
          mdx_analyzer = {
            package = pkgs.mdx-language-server;
            args = [ "--stdio" ];
            initializationOptions.typescript = {
              enabled = true;
              inherit tsdk;
            };
            editors.zed.name = "mdx-analyzer";
          };
          # Type-aware linting runs tsgolint.
          oxlint = {
            package = pkgs.oxlint;
            args = [ "--lsp" ];
            linter = true;
            initializationOptions.settings = {
              run = "onType";
              typeAware = true;
            };
            editors.zed.extension = "oxc";
          };
          tailwindcss = {
            package = pkgs.tailwindcss-language-server;
            args = [ "--stdio" ];
            editors.zed.name = "tailwindcss-language-server";
          };
          # The native language server of TypeScript 7, which Zed runs in place of vtsls.
          tsc = {
            package = pkgs.typescript;
            args = [
              "--lsp"
              "--stdio"
            ];
            editors.zed.name = "vtsls";
          };
          # keep-sorted end
        };

        tools = {
          # Every language oxfmt can parse. The CLI sidesteps the workspace detection of its
          # language server, so a lone file formats the same way as one in a node project.
          oxfmt = {
            package = pkgs.oxfmt;
            stdinArgs = [
              "--stdin-filepath"
              "{file}"
            ];
          };
          oxlint = {
            package = pkgs.oxlint;
            args = [ "--fix" ];
            # Exits with 1 while unfixable lints remain.
            editors.neovim.exitCodes = [
              0
              1
            ];
            editors.zed.codeAction = "source.fixAll.oxc";
          };
        };
      };
    };
}
