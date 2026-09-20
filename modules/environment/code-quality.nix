# Static analysis: linters, structural search and dead-code detection, across the
# languages this config works in. Language toolchains, language servers and formatters
# stay with their ecosystem in `optionals.nix`, and security, licensing and
# bill-of-materials tooling lives in `supply-chain.nix`.
{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.packages = with pkgs; [
        ## cross language

        # structural search, the way to ask whether the repository already has a shape
        ast-grep
        # duplication, which is what turns a reuse candidate into a measurement.
        # covers 220 languages, though not nix
        jscpd
        # size and cyclomatic complexity, to rank where simplification pays
        scc
        (python3Packages.toPythonApplication python3Packages.lizard)
        rust-code-analysis
        # spelling and grammar, in identifiers, comments and prose
        typos
        harper
        # link rot
        lychee

        ## typescript

        # unused files, exports and dependencies, which nothing else here reports
        knip

        ## python

        perflint
        deptry
        (python3Packages.toPythonApplication python3Packages.vulture)

        ## go

        golangci-lint
        nilaway

        ## nix

        statix
        deadnix

        ## rust

        cargo-machete
        cargo-udeps

        ## shell, bash and sh only since shellcheck does not parse fish

        shellcheck
      ];
    };
}
