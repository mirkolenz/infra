# Supply-chain evidence: what a product ships, what is wrong with it, and what it is
# allowed to be shipped under.
{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.packages =
        with pkgs;
        [
          ## shared: the bill of materials both a security and a licensing audit read

          # generation and conversion
          syft
          cdxgen
          # the extractor library behind osv-scanner, exposed as its own scanner. syft and
          # cdxgen read more lockfiles, so this one earns its place on images and layers
          osv-scalibr
          cyclonedx-cli
          sbomnix
          # querying, assembling and scoring a document
          sbom-utility
          sbomasm
          sbomqs

          ## security

          # vulnerabilities against a document or a tree
          grype
          trivy
          osv-scanner
          vulnix
          bomber-go
          cve-bin-tool
          # ecosystem native advisory scanners, which resolve a vulnerable symbol
          # rather than a vulnerable version and so report far fewer false positives.
          # python is covered by `uv audit`, which ships with uv itself
          govulncheck
          cargo-audit
          # secrets, including the ones reachable only through git history
          # validates a hit against the live service, so a dead string stops outranking a
          # live credential
          kingfisher
          gitleaks
          trufflehog
          # static analysis, bearer covering data flow and privacy
          semgrep
          bearer
          # build, release and artifact integrity
          zizmor
          actionlint
          scorecard
          cosign
          slsa-verifier
          witness

          ## licensing

          # declared licenses and copyright headers
          reuse
          sbom-compliance-tool
          # detection from file contents
          scancode-toolkit
          askalono
          licensee
          # compatibility and normalization
          licomp-toolkit
          lookup-license
          foss-flame
          # snippet origin
          scanoss-py
          # per ecosystem attribution and policy
          cargo-deny
          cargo-about
          go-licenses
        ]
        ++ lib.optionals config.custom.features.graphical.enable [
          # desktop uis for auditing scan results
          scanoss-cc
          sbom-workbench
        ];
    };
}
