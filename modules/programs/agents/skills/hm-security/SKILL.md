---
name: hm-security
description: |
  Audits security under the EU Cyber Resilience Act, covering first-party code, dependencies, and the shipped bill of materials.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks for a security audit, a CRA review, or a vulnerability scan.
---

Judge a product against CRA Annex I, Part I (security properties) and Part II (vulnerability handling).
Every finding cites tool output, never a guess, and a command that could not run is itself a gap in the evidence.

## Scope

The argument names the target and defaults to uncommitted changes: a commit, a range, a branch or a pull request puts you in diff mode, a path or the whole tree in file mode.
Both the first-party code and everything it ships are in scope, so the bill of materials is the starting artifact rather than an afterthought.

## Tools

These are installed.
Decide per tool whether to run it yourself into a shared scratch directory, or to name it in an agent's prompt and let the agent run it.
The bill of materials is worth producing once, since every angle rests on it.
A scan only one angle reads is better delegated, since its output then never enters your context.
Either way, run what the ecosystems present call for and record what was skipped, since an unscanned tree proves nothing.

```sh
# nix: the bill of materials the repository builds itself, when it has one
nix build .#sbom

# syft, cdxgen: a bill of materials from a tree or an image
syft scan dir:. -o cyclonedx-json=sbom.cdx.json
cdxgen -o sbom.cdx.json

# scalibr: reads more ecosystems than either, and inspects images and layers.
# reach for it when the tree is polyglot or a container is in scope
scalibr -root=. -o cdx-json=sbom.cdx.json

# cdxgen-evinse: adds call stacks, separating a component that ships from one the product reaches
cdxgen-evinse -i sbom.cdx.json -o sbom.evinse.json

# sbomasm: merges several documents into one product bill
sbomasm assemble -o product.cdx.json <bom> <bom>

# sbomqs: scores a document against BSI TR-03183-2, the profile the CRA points at.
# --ntia, --fsct and --oct cover the other regimes
sbomqs compliance --bsi <bom>

# sbom-utility, cyclonedx: whether the document itself is valid, and what a release changed
sbom-utility validate -i <bom>
cyclonedx validate --input-file <bom>
cyclonedx diff <previous> <current>

# vulnxscan: grype, osv and vulnix in one triaged csv
vulnxscan --sbom <bom> --triage

# trivy, bomber, sbom-cve-check, osv-detector: independent databases, worth a second opinion
trivy sbom <bom>
bomber scan <bom>
osv-detector <lockfile>

# govulncheck, pip-audit, cargo-audit: resolve a vulnerable symbol rather than a vulnerable
# version, so prefer their verdict when they disagree with a scanner
govulncheck ./...
pip-audit
cargo audit

# cve-bin-tool: shipped binaries that carry no manifest
cve-bin-tool <dir>

# vulnix, sbomnix, nix_outdated: the nix runtime closure
vulnix --closure <path>
sbomnix <path>

# kingfisher, gitleaks, trufflehog: secrets, including the ones only the history carries.
# kingfisher scans locally and never uploads the code, but without --no-validate it sends each
# candidate credential to the provider that issued it to test whether it is live. ask first
kingfisher scan --no-validate .
gitleaks detect
trufflehog git file://.

# semgrep: rule-driven defects.
# it reports pseudonymous metrics whenever a config pulls from its server, so keep the flag
semgrep --config auto --metrics=off

# bearer: data-flow and privacy risk
bearer scan .

# ast-grep: matches a shape the rules miss
ast-grep run --pattern '<shape>' <path>

# zizmor, actionlint: ci workflows
zizmor .github/workflows
actionlint

# scorecard: project security posture
scorecard --local .

# cosign, slsa-verifier, witness: whether the release chain is attested
cosign verify <artifact>

# gh: the repository's own dependabot alerts and security advisories
gh api repos/<owner>/<repo>/dependabot/alerts
```

## Angles

Cover every angle below.
How many agents that takes is yours to choose: give one agent several angles when they read the same material, since the cost is in reading it twice, not in the extra angle.
Skip an angle whose subject the target does not contain, and say which and why, so a quiet gap never reads as a clean run.
Tell each agent which output it is given and which tools it should run itself, so the same whole-tree scan does not run several times by accident.

- Known vulnerabilities: triage every reported CVE, deduplicating by purl plus CVE.
  Drop what reachability proves unreachable and name the fixed version for the rest.
  Annex I Part II (1) and (2).
- Bill of materials: the BOM against the lockfiles, vendored trees and base images actually shipped.
  A component that ships unnamed, a document that fails validation, or a missing version, license or supplier field is a finding.
  Annex I Part II (1).
- First-party code: each tool hit confirmed in context, then what the rules miss, meaning injection, deserialization, path traversal, broken authorization and weak cryptography.
  Annex I Part I (2)(a) to (2)(f).
- Secrets and configuration: every secret hit verified, including history-only ones, and whether defaults ship secure.
  A committed credential is a finding even after rotation, since the history still carries it.
  Annex I Part I (2)(b) and (2)(c).
- Attack surface and updates: exposed ports, endpoints and privileges against what the product needs, plus pinned dependencies, an attested release chain, a security policy and an update channel.
  Annex I Part I (2)(j) and Part II (2), (5), (7).

## Output

A finding names a file and line, states the defect in one sentence, and gives the exploit scenario, the CRA clause, and the fix.
Rank by exploitability and merge the ones naming the same defect at the same place.
Then list every command and every angle that did not run and why, since a gap in the evidence is itself a conformity gap.
