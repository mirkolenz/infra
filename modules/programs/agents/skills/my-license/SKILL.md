---
name: my-license
description: |
  Audits license, copyright, and patent compliance across first-party code and its dependencies, including copied snippets and attribution.
  The argument names a mode (a diff or a path) and a layer (`repo`, `deps` or `full`), defaulting to uncommitted changes over the full product.
  Use when the user asks for a license audit, a copyright or attribution review, or a patent exposure check.
---

Judge whether the product may legally be distributed under the license it claims, and whether anything in it belongs to someone else.
Every finding cites tool output and names the obligation that is breached, and a command that could not run leaves the claim unproven.

Regulatory compliance belongs to the `my-legal` skill, and vulnerabilities to `my-security`.
This skill judges a product against the terms it was granted, which is a question the detectors and the licence texts answer.
When a finding turns on what the statute says instead, meaning whether a fragment is protectable at all, whether a mining opt-out was reserved, or whether a technique infringes, state the question and hand it to `my-legal` rather than answering it here.

## Scope

The mode defaults to uncommitted changes: a commit, a range, a branch or a pull request is diff mode, and a path or the whole tree is file mode.
The layer defaults to `full`: `repo` is the first-party sources, `deps` is everything the product ships, and `full` is the two together.

Fix the outbound license first from `LICENSE`, `REUSE.toml` and the package manifest, whatever the layer, since every finding is judged against it.

## Tools

These are installed.
Decide per tool whether to run it yourself into a shared scratch directory, or to name it in an agent's prompt and let the agent run it.
The bill of materials and the outbound licence are worth settling once, since every angle rests on them.
A detector only one angle reads is better delegated, since its output then never enters your context.
Either way, run what the ecosystems present call for and record what was skipped, since an unscanned tree proves nothing.
A detector that cannot reach its knowledge base reports no match rather than an error, so confirm it ran before reading silence as a clean result.

```sh
# nix: the bill of materials the repository builds itself, when it has one
nix build .#sbom

# syft, cdxgen: a bill of materials from the tree, and the two that read the most ecosystems.
# both read uv.lock and package-lock.json, and cdxgen also resolves flake.lock inputs
syft scan dir:. -o cyclonedx-json=sbom.cdx.json
cdxgen -o sbom.cdx.json

# scalibr: the one that inspects an image and its layers, so reach for it when a container ships
scalibr -root=. -o cdx-json=sbom.cdx.json

# sbom-utility: what the bill of materials claims
sbom-utility license list -i <bom>
sbom-utility license policy

# trivy, osv-scanner: what the ecosystems claim
trivy fs --scanners license --license-full .
osv-scanner scan source -r . --licenses

# licomp-toolkit: whether one licence may be distributed under another, aggregating the OSADL
# matrix, Dwheeler, the GNU guide, Hermione, DoubleOpen, the OSLC handbook and reclicense.
# prefer its verdict over your own reading
licomp-toolkit verify -il <inbound> -ol <outbound>

# sbom_compliance_tool: the same compatibility question across a whole bill of materials
sbom_compliance_tool <bom>

# lookup-license: resolves prose such as "Apache 2.0 License" to an SPDX identifier
lookup-license "<prose>"

# flame: normalizes and expands licence metadata
flame <expression>

# askalono, licensee: fast licence detection from file contents
askalono crawl .
licensee detect .

# scancode: thorough, slow, so keep it for the files where the fast pass disagrees
scancode -clpi --json-pp scancode.json .

# cargo-about, go-licenses, cargo-deny: the notice set, failing on a banned licence
cargo about generate
go-licenses report ./...
cargo deny check licenses

# reuse: header and LICENSES/ compliance, where the repo has adopted it
reuse lint

# scanoss-py: whether first-party files contain code taken from elsewhere.
# it queries api.osskb.org, uploading winnowing fingerprints and never the file contents
scanoss-py scan . --output scanoss.json
scanoss-py inspect copyleft                   # the fragments that argue a derivative work
scanoss-py inspect undeclared

# the same, narrowed to what changed, which is where agent-written code shows up
git diff --name-only <range> > changed.txt
scanoss-py scan --files-from changed.txt --output scanoss.json

# gh: the licence a dependency's own repository declares, when a manifest and a detector disagree
gh api repos/<owner>/<repo>/license
```

## Angles

Cover every angle below whose layer is in scope, the first three under `repo`, the next three under `deps`, and patent exposure under both.
How many agents that takes is yours to choose: give one agent several angles when they read the same material, since the cost is in reading it twice, not in the extra angle.
Skip an angle whose subject the target does not contain, and say which and why, so a quiet gap never reads as a clean run.
Tell each agent which output it is given and which tools it should run itself, so the same whole-tree scan does not run several times by accident.

- Copied code: snippet matches and high-confidence detector hits inside first-party files, naming the upstream and its terms.
  Code an AI agent wrote is a live source of this, since a model can reproduce what it was trained on, so weight recently changed files rather than only vendored trees.
  A fragment with no header is the whole finding: the remedy is removal or the upstream licence and attribution, never a quiet rewrite to make the detector stop matching.
- Third-party content: text, images, fonts, icons, sample data and model weights shipped with no licence that permits the use, and whether the terms of the ones that do are met.
  A font or an asset licensed for one medium but shipped in another is a finding.
- Authorship and headers: the outbound licence actually granted, copyright notices and SPDX headers against `reuse`, and contributions whose provenance or employer assignment nothing records.
  Scraped or mined content is a finding when no reservation was checked, and whether the reservation binds is a question for `my-legal`.
- Outbound compatibility: every dependency licence against the outbound licence, with `licomp-toolkit` as the verdict.
  Copyleft reaching a permissive or proprietary product, source-available terms such as BUSL, SSPL or Elastic, and non-commercial or no-derivatives terms.
  Name the linkage, since a build-time or test-only dependency is not a distribution.
- Undeclared and conflicting: a component with no licence, a string that resolves to no SPDX identifier, or a declaration contradicting what the detectors found.
  A license that cannot be determined is a finding, not an omission.
- Attribution and notices: whether the product ships the full license text and retained copyright notices for every dependency that requires them, whether Apache-2.0 `NOTICE` files are propagated, and whether the generated attribution set matches what is distributed.
- Patent exposure: terms carrying patent obligations or termination clauses, such as Apache-2.0 section 3, GPL-3.0 section 11 and MPL-2.0 section 5, and permissive licenses with no patent grant where the product relies on a patented technique.
  State what triggers the termination, and for an unlicensed technique name the patent or family and the lines that practise it, leaving the infringement verdict to `my-legal`.

## Output

A finding names a file and line, states the breach in one sentence, and gives the obligation, the upstream license or norm, and the remedy.
Rank by distribution risk with anything blocking release first, and merge the ones naming the same obligation for the same component.
Then list every command and every angle that did not run and why, since an unscanned tree proves nothing, list the questions handed to `my-legal`, and close by stating that this is a review aid and not legal advice.
