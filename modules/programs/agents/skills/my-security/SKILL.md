---
name: my-security
description: |
  Audits code, dependencies, and the shipped bill of materials for vulnerabilities, exploitable defects, and leaked secrets.
  The argument names a mode (a diff or a path) and a layer (`repo`, `deps` or `full`), defaulting to uncommitted changes over the full product.
  Use when the user asks for a security audit, a vulnerability scan, or a supply chain review.
---

Find what an attacker can reach and what it costs them, and prove it with tool output rather than a guess.
A command that could not run is itself a gap in the evidence.

Conformity paperwork under the CRA and NIS2 belongs to the `my-legal` skill, and licence, copyright and patent obligations to `my-license`.
Report the technical facts they need rather than judging the law yourself.

## Scope

The mode defaults to uncommitted changes: a commit, a range, a branch or a pull request is diff mode, and a path or the whole tree is file mode.
The layer defaults to `full`: `repo` is the first-party sources, `deps` is everything the product ships, and `full` is the two together.

Whenever `deps` is in scope the bill of materials is the starting artifact rather than an afterthought, since an unlisted component is an unscanned one.

## Tools

These are installed.
Decide per tool whether to run it yourself into a shared scratch directory, or to name it in an agent's prompt and let the agent run it.
The bill of materials is worth producing once, since every angle rests on it.
A scan only one angle reads is better delegated, since its output then never enters your context.
Either way, run what the ecosystems present call for and record what was skipped, since an unscanned tree proves nothing.
A scanner that cannot reach its database reports a clean tree rather than an error, so confirm each one loaded its data before believing a quiet result.

```sh
# nix: the bill of materials the repository builds itself, when it has one
nix build .#sbom

# syft, cdxgen: a bill of materials from a tree, and the two that read the most ecosystems.
# both read uv.lock and package-lock.json. syft is the faster one and queries nothing, cdxgen
# is the only one that turns flake.lock into components, one per input at its locked revision
syft scan dir:. -o cyclonedx-json=sbom.cdx.json
cdxgen -o sbom.cdx.json

# scalibr: the one that inspects an image and its layers, so reach for it when a container ships
scalibr -root=. -o cdx-json=sbom.cdx.json

# cdxgen-evinse: adds call stacks, separating a component that ships from one the product reaches
cdxgen-evinse -i sbom.cdx.json -o sbom.evinse.json

# sbomasm: merges several documents into one product bill
sbomasm assemble -o product.cdx.json <bom> <bom>

# sbomqs: scores a document, which is how a bill too thin to scan against shows up
sbomqs compliance --bsi <bom>

# sbom-utility, cyclonedx: whether the document itself is valid, and what a release changed
sbom-utility validate -i <bom>
cyclonedx validate --input-file <bom>
cyclonedx diff <previous> <current>

# vulnxscan: grype, osv and vulnix in one triaged csv
vulnxscan --sbom <bom> --triage

# trivy, bomber: independent databases, worth a second opinion.
# bomber defaults to osv, so `--provider ossindex` is what makes it an independent one
trivy sbom <bom>
bomber scan --provider ossindex <bom>

# govulncheck, uv audit, cargo-audit: resolve a vulnerable symbol rather than a vulnerable
# version, so prefer their verdict when they disagree with a scanner.
# `uv audit` reads uv.lock and asks osv, and `--frozen` keeps it from re-locking against pypi.
# `--no-dev` is the honest scope for a shipped product, since a dev group is not distributed
govulncheck ./...
uv audit --frozen
cargo audit

# uv export: the bridge for anything that still only speaks requirements.txt
uv export --frozen --format requirements.txt --no-emit-project

# cve-bin-tool: shipped binaries that carry no manifest.
# its other feeds are unreachable here, so disable them and keep the two that resolve,
# otherwise it spends the run retrying hosts it cannot have
cve-bin-tool -d CURL,EPSS,GAD,PURL2CPE,REDHAT,RSD <dir>

# vulnix, sbomnix, nix_outdated: the nix runtime closure
vulnix --closure <path>
sbomnix <path>

# kingfisher, gitleaks, trufflehog: secrets, including the ones only the history carries.
# kingfisher scans locally and never uploads the code, but without --no-validate it sends each
# candidate credential to the provider that issued it to test whether it is live. ask first
kingfisher scan --no-validate .
gitleaks detect
trufflehog git file://.

# semgrep: rule-driven defects
semgrep --config auto

# bearer: the security report, meaning data flowing into a sink it should not reach.
# its privacy and dataflow reports are my-legal's, so name the report rather than taking the default
bearer scan --report security .

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

Cover every angle below whose layer is in scope, the first four under `repo` and the last two under `deps`.
How many agents that takes is yours to choose: give one agent several angles when they read the same material, since the cost is in reading it twice, not in the extra angle.
Skip an angle whose subject the target does not contain, and say which and why, so a quiet gap never reads as a clean run.
Tell each agent which output it is given and which tools it should run itself, so the same whole-tree scan does not run several times by accident.

- First-party code: each tool hit confirmed in context, then what the rules miss, meaning injection, deserialization, path traversal, broken authorization, unsafe memory or concurrency, and weak or misused cryptography.
  Name the untrusted input that reaches the sink, since that is what separates a defect from a warning.
- Secrets and configuration: every secret hit verified, including history-only ones, and whether defaults ship secure.
  A committed credential is a finding even after rotation, since the history still carries it.
- Attack surface: exposed ports, endpoints, privileges and trust boundaries against what the product actually needs.
  Authentication and authorization gaps, missing rate limits, and anything reachable before a login is checked.
- Build and release integrity: ci workflows, pinned dependencies and actions, an attested release chain, a security policy and a working update channel.
  A workflow that runs untrusted input with write permissions is an exploit path into the product.
- Known vulnerabilities: triage every reported CVE, deduplicating by purl plus CVE.
  Drop what reachability proves unreachable and name the fixed version for the rest, with the exploit path for anything reachable from untrusted input.
- Bill of materials: the document against the lockfiles, vendored trees and base images actually shipped.
  A component that ships unnamed, a document that fails validation, or a missing version or supplier field is a finding, because it is a component no scanner ever looked at.

## Output

A finding names a file and line, states the defect in one sentence, and gives the exploit scenario and the fix.
Rank by exploitability and merge the ones naming the same defect at the same place.
Then list every command and every angle that did not run and why, since a gap in the evidence is a gap in the audit.
