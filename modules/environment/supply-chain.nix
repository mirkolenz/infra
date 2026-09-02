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
          # sbom generation and conversion
          syft
          cdxgen
          sbom-tool
          cyclonedx-cli
          sbom-utility
          sbomnix
          # language specific cyclonedx generators
          # cyclonedx-npm is not packaged in nixpkgs since upstream ships no lockfile,
          # so it is provided as an npx alias instead
          cyclonedx-python
          cyclonedx-gomod
          cargo-cyclonedx
          # vulnerabilities
          grype
          trivy
          osv-scanner
          osv-detector
          vulnix
          # licenses, copyrights and code origin
          reuse
          scancode-toolkit
          scanoss-py
          scanoss-js
        ]
        ++ lib.optionals config.custom.features.graphical.enable [
          # desktop uis for auditing scan results
          scanoss-cc
          sbom-workbench
        ];
    };
}
