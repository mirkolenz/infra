---
name: my-security
description: |
  Audits code, dependencies, and the shipped bill of materials for vulnerabilities, exploitable defects, and leaked secrets.
  The argument names a mode (a diff or a path) and a layer (`repo`, `deps` or `full`), defaulting to uncommitted changes over the full product.
  Use when the user asks for a security audit, a vulnerability scan, or a supply chain review.
---

Find what an attacker can reach and what it costs them, and prove it with tool output rather than a guess.
CRA and NIS2 paperwork belongs to `my-legal`, and license obligations to `my-license`, so report the technical facts they need without judging the law.

## Scope

A commit, range, branch, or pull request is diff mode, and a path or the whole tree is file mode.
The layer `repo` is the first-party sources, `deps` is everything the product ships, and `full` is both.
Whenever `deps` is in scope, start from the bill of materials, since an unlisted component is an unscanned one.

## Tools

These are installed.
Run a tool once into a shared scratch directory when several angles read it, otherwise let the agent that needs it run it.
Produce the bill of materials once, since every angle rests on it.
A scanner that cannot reach its database reports a clean tree rather than an error, so confirm it loaded its data.
Record every command that was skipped or failed, since an unscanned tree proves nothing.

```sh
# nix: the bill of materials the repository builds itself, when it has one
nix build .#sbom

# syft, cdxgen: a bill of materials from the tree, both read uv.lock and package-lock.json.
# syft is faster and offline, cdxgen also turns flake.lock inputs into components
syft scan dir:. -o cyclonedx-json=sbom.cdx.json
cdxgen -o sbom.cdx.json

# scalibr: container images and their layers
scalibr -root=. -o cdx-json=sbom.cdx.json

# cdxgen-evinse: call stacks, separating a shipped component from a reached one
cdxgen-evinse -i sbom.cdx.json -o sbom.evinse.json

# sbomasm: merge several documents into one product bill
sbomasm assemble -o product.cdx.json <bom> <bom>

# sbomqs: score a document, exposing a bill too thin to scan against
sbomqs compliance --bsi <bom>

# sbom-utility, cyclonedx: validate a document, and diff two releases
sbom-utility validate -i <bom>
cyclonedx validate --input-file <bom>
cyclonedx diff <previous> <current>

# vulnxscan: grype, osv, and vulnix in one triaged csv
vulnxscan --sbom <bom> --triage

# trivy, bomber: independent databases for a second opinion,
# bomber defaults to osv, so pass `--provider ossindex`
trivy sbom <bom>
bomber scan --provider ossindex <bom>

# govulncheck, uv audit, cargo-audit: resolve vulnerable symbols, so prefer their verdict.
# `--frozen` keeps uv from re-locking, and `--no-dev` scopes it to what ships
govulncheck ./...
uv audit --frozen
cargo audit

# uv export: requirements.txt for tools that need it
uv export --frozen --format requirements.txt --no-emit-project

# cve-bin-tool: shipped binaries without a manifest,
# with the unreachable feeds disabled so it does not retry them
cve-bin-tool -d CURL,EPSS,GAD,PURL2CPE,REDHAT,RSD <dir>

# vulnix, sbomnix: the nix runtime closure
vulnix --closure <path>
sbomnix <path>

# kingfisher, gitleaks, trufflehog: secrets, including history-only ones.
# kingfisher without `--no-validate` sends candidates to their issuer, so ask first
kingfisher scan --no-validate .
gitleaks detect
trufflehog git file://.

# semgrep, ast-grep: rule-driven defects, and shapes the rules miss
semgrep --config auto
ast-grep run --pattern '<shape>' <path>

# bearer: data flowing into a sink it should not reach.
# the privacy and dataflow reports belong to my-legal
bearer scan --report security .

# zizmor, actionlint: ci workflows
zizmor .github/workflows
actionlint

# scorecard: project security posture
scorecard --local .

# cosign, slsa-verifier, witness: whether the release chain is attested
cosign verify <artifact>

# gh: dependabot alerts and security advisories
gh api repos/<owner>/<repo>/dependabot/alerts
```

## Angles

Cover every angle whose layer is in scope, the first four under `repo` and the last two under `deps`.
Group angles that read the same material into one agent, and tell each agent which output it gets and which tools it runs.
Skip an angle whose subject the target does not contain, and say so.

- First-party code: each tool hit confirmed in context, then injection, deserialization, path traversal, broken authorization, unsafe memory or concurrency, and misused cryptography.
  Name the untrusted input that reaches the sink.
- Secrets and configuration: every secret hit verified, and whether defaults ship secure.
  A committed credential is a finding even after rotation.
- Attack surface: exposed ports, endpoints, privileges, and trust boundaries against what the product needs.
  Authentication and authorization gaps, missing rate limits, and anything reachable before login.
- Build and release integrity: ci workflows, pinned dependencies and actions, an attested release chain, a security policy, and an update channel.
  A workflow that runs untrusted input with write permissions is an exploit path.
- Known vulnerabilities: every CVE triaged and deduplicated by purl plus CVE.
  Drop what is proven unreachable, and give the fixed version and the exploit path for the rest.
- Bill of materials: the document against the lockfiles, vendored trees, and base images actually shipped.
  An unnamed component, a failed validation, or a missing version or supplier is a finding.

## Output

Each finding names the file and line, states the defect in one sentence, and gives the exploit scenario and the fix.
Rank by exploitability, and merge findings of the same defect at the same place.
Close with every command and angle that did not run and why.
