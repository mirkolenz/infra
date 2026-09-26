---
name: my-license
description: |
  Audits license, copyright, and patent compliance across first-party code and its dependencies, including copied snippets and attribution.
  The argument names a mode (a diff or a path) and a layer (`repo`, `deps` or `full`), defaulting to uncommitted changes over the full product.
  Use when the user asks for a license audit, a copyright or attribution review, or a patent exposure check.
---

Judge whether the product may be distributed under the license it claims, and whether anything in it belongs to someone else.
Every finding cites tool output and names the breached obligation.
Regulatory law belongs to `my-legal` and vulnerabilities to `my-security`.
When a finding turns on the statute, such as whether a fragment is protectable, a mining opt-out binds, or a technique infringes, hand the question to `my-legal`.

## Scope

A commit, range, branch, or pull request is diff mode, and a path or the whole tree is file mode.
The layer `repo` is the first-party sources, `deps` is everything the product ships, and `full` is both.
First fix the outbound license from `LICENSE`, `REUSE.toml`, and the package manifest, since every finding is judged against it.

## Tools

These are installed.
Run a tool once into a shared scratch directory when several angles read it, otherwise let the agent that needs it run it.
Settle the bill of materials and the outbound license once, since every angle rests on them.
A detector that cannot reach its knowledge base reports no match rather than an error, so confirm it ran.
Record every command that was skipped or failed, since an unscanned tree proves nothing.

```sh
# nix: the bill of materials the repository builds itself, when it has one
nix build .#sbom

# syft, cdxgen: a bill of materials from the tree, both read uv.lock and package-lock.json.
# cdxgen also resolves flake.lock inputs
syft scan dir:. -o cyclonedx-json=sbom.cdx.json
cdxgen -o sbom.cdx.json

# scalibr: container images and their layers
scalibr -root=. -o cdx-json=sbom.cdx.json

# sbom-utility: the licenses the bill of materials claims
sbom-utility license list -i <bom>
sbom-utility license policy

# trivy, osv-scanner: the licenses the ecosystems claim
trivy fs --scanners license --license-full .
osv-scanner scan source -r . --licenses

# licomp-toolkit: whether one license may be distributed under another,
# aggregating seven compatibility sources, so prefer its verdict over your own reading
licomp-toolkit verify -il <inbound> -ol <outbound>

# sbom_compliance_tool: the same question across a whole bill of materials
sbom_compliance_tool <bom>

# lookup-license, flame: resolve prose to an SPDX identifier, and normalize expressions
lookup-license "<prose>"
flame <expression>

# askalono, licensee: fast detection from file contents
askalono crawl .
licensee detect .

# scancode: thorough and slow, only where the fast pass disagrees
scancode -clpi --json-pp scancode.json .

# cargo-about, go-licenses, cargo-deny: the notice set, failing on a banned license
cargo about generate
go-licenses report ./...
cargo deny check licenses

# reuse: header and LICENSES/ compliance, where the repository adopted it
reuse lint

# scanoss-py: code taken from elsewhere, uploading fingerprints and never contents.
# `inspect copyleft` lists the fragments that argue a derivative work
scanoss-py scan . --output scanoss.json
scanoss-py inspect copyleft
scanoss-py inspect undeclared

# scanoss-py narrowed to changed files, where agent-written code shows up
git diff --name-only <range> > changed.txt
scanoss-py scan --files-from changed.txt --output scanoss.json

# gh: the license a dependency's repository declares, when manifest and detector disagree
gh api repos/<owner>/<repo>/license
```

## Angles

Cover every angle whose layer is in scope, the first three under `repo`, the next three under `deps`, and patent exposure under both.
Group angles that read the same material into one agent, and tell each agent which output it gets and which tools it runs.
Skip an angle whose subject the target does not contain, and say so.

- Copied code: snippet matches and high-confidence detector hits in first-party files, naming the upstream and its terms.
  AI-written code can reproduce training data, so weight recently changed files.
  The remedy is removal or the upstream license and attribution, never a rewrite that just silences the detector.
- Third-party content: text, images, fonts, icons, sample data, and model weights shipped without a license permitting the use, or with unmet terms.
  An asset licensed for one medium but shipped in another is a finding.
- Authorship and headers: the outbound license, copyright notices, and SPDX headers against `reuse`, and contributions with unrecorded provenance or employer assignment.
  Scraped or mined content with no checked reservation is a finding.
- Outbound compatibility: every dependency license against the outbound license, with `licomp-toolkit` as the verdict.
  Copyleft in a permissive or proprietary product, source-available terms such as BUSL, SSPL, or Elastic, and non-commercial or no-derivatives terms.
  Name the linkage, since a build-time or test-only dependency is not distributed.
- Undeclared and conflicting: a component without a license, a string with no SPDX identifier, or a declaration contradicting the detectors.
  An undeterminable license is a finding.
- Attribution and notices: full license texts and copyright notices for every dependency requiring them, propagated Apache-2.0 `NOTICE` files, and a generated attribution set matching what ships.
- Patent exposure: patent obligations and termination clauses such as Apache-2.0 section 3, GPL-3.0 section 11, and MPL-2.0 section 5, and permissive licenses without a patent grant where a patented technique is used.
  State the termination trigger, and for an unlicensed technique name the patent and the lines practising it, leaving infringement to `my-legal`.

## Output

Each finding names the file and line, states the breach in one sentence, and gives the obligation, the upstream license or norm, and the remedy.
Rank by distribution risk with release blockers first, and merge findings of the same obligation for the same component.
Close with every command and angle that did not run and why, the questions handed to `my-legal`, and a note that this is a review aid and not legal advice.
