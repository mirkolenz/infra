---
name: my-legal
description: |
  Reviews documents and source code against German and EU law, covering data protection, the AI Act, regulatory cybersecurity duties, contract terms, publication duties, and the copyright and patent statutes behind a licensing question.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks for a legal or regulatory compliance review.
---

Review the target for legal compliance, over prose documents and the code that implements what they promise.
Every finding cites a norm fetched from an official source in this session, and a norm you did not fetch cannot back a finding.
License scanning belongs to `my-license` and vulnerability scanning to `my-security`, so reuse their reports and answer the statutory questions they hand over.

## Scope

A commit, range, branch, or pull request is diff mode, and a path or the whole tree is file mode.
Documents (`md`, `typ`, `tex`, `rst`, `txt`, `pdf`) and source code carry different obligations, so treat them separately.
Markup can hide a clause, so read documents as text, and render them where the output differs.

## Tools

These are installed.
Run a tool once and share its output when several angles read it, otherwise let the agent that needs it run it.
Fetch a norm several angles rest on once.

```sh
# eurlex: EU law from EUR-Lex and CELLAR.
# resolve a reference to a CELEX, then fetch the act in DEU and ENG,
# its application dates, amendments, implementing acts, and CJEU case law
eurlex resolve "Regulation 2016/679"
eurlex get <celex> --lang DEU
eurlex metadata <celex>
eurlex amendments <celex>
eurlex implementing <celex>
eurlex case-law <celex>

# recht: German federal law from gesetze-im-internet.de.
# the catalogue, a table of contents, and one provision
recht list
recht list BGB
recht get BGB 823

# bearer: which personal data flows where.
# the security report belongs to my-security
bearer scan --report privacy .
bearer scan --report dataflow .

# semgrep, ast-grep: logging, telemetry, retention, and consent handling
semgrep --config auto
ast-grep run --pattern '<shape>' <path>

# xh: guidance that has no CELEX
xh --download <url>

# pdftotext, pdftohtml, pdftoppm: a pdf as text, as structure, and as page images
pdftotext -layout <pdf> -
pdftohtml -s -i -noframes -stdout <pdf> | pandoc -f html -t markdown
pdftoppm -png -r 150 <pdf> page

# pandoc, typst, latexmk: a document as text, and rendered
pandoc -t plain <file>
typst compile <file>
latexmk <file>

# lychee: citations and cross-references that no longer resolve
lychee .

# typos, harper-cli: wording defects that change what a clause means
typos
harper-cli lint <file>
```

## Starting points

These are pointers and not authority, so fetch before citing.
Confirm a German abbreviation with `recht list`, since only the catalogue spelling resolves.

### EU law, via `eurlex get <celex>`

- DSGVO, Regulation (EU) 2016/679, `32016R0679`
  - legal basis Art 6, processors Art 28, transfers Chapter V, rights Art 15 to 22
- KI-VO, Regulation (EU) 2024/1689, `32024R1689`
  - prohibited practices Art 5, high-risk Annex III, transparency Art 50, GPAI Chapter V
- Cyberresilienz-VO, Regulation (EU) 2024/2847, `32024R2847`
  - essential requirements Annex I, technical documentation Annex VII, reporting Art 14
- NIS2, Directive (EU) 2022/2555, `32022L2555`
  - risk management Art 21, reporting Art 23
- NIS2 implementing act, Commission Implementing Regulation (EU) 2024/2690, `32024R2690`
  - the technical requirements behind NIS2 Art 21
- Produkthaftungs-RL, Directive (EU) 2024/2853, `32024L2853`
  - software as a product, for what is placed on the market after 9 December 2026
- Data Act, Regulation (EU) 2023/2854, `32023R2854`
- DSA, Regulation (EU) 2022/2065, `32022R2065`
- ePrivacy-RL, Directive 2002/58/EC, `32002L0058`
  - Art 5(3) terminal equipment, implemented by TDDDG 25
- Cybersecurity Act, Regulation (EU) 2019/881, `32019R0881`
  - the certification schemes the CRA builds on
- DSM-Urheberrechts-RL, Directive (EU) 2019/790, `32019L0790`
  - Art 4 text and data mining, the opt-out an AI training claim turns on
- Barrierefreiheits-RL, Directive (EU) 2019/882, `32019L0882`

### German federal law, via `recht get <abbr> <norm>`

- BGB, Bürgerliches Gesetzbuch
  - AGB control 305 to 310, delict 823
- BDSG, Bundesdatenschutzgesetz
  - the openings the DSGVO leaves, employee data 26
- TDDDG, Telekommunikation-Digitale-Dienste-Datenschutz-Gesetz
  - 25, consent for storing or reading on terminal equipment
- DDG, Digitale-Dienste-Gesetz
  - 5, the Impressum, replacing TMG since 2024
- UrhG, Urheberrechtsgesetz
  - 44b text and data mining, 69a to 69g software, 69b works created in employment
- PatG, Patentgesetz
  - 9, the acts a patent reserves to its proprietor, and 11 the exemptions
- UWG, Gesetz gegen den unlauteren Wettbewerb
- ProdHaftG, Produkthaftungsgesetz
  - until Directive (EU) 2024/2853 is transposed
- GeschGehG, Geschäftsgeheimnisgesetz

### Guidance, via `xh`

Guidance binds nobody, so cite the article it interprets and name the guidance as support.

- Code of Practice on Transparency of AI-generated Content, for KI-VO Art 50
  - digital-strategy.ec.europa.eu/en/policies/code-practice-ai-generated-content
  - confirmed adequate by the Commission, so adherence is evidence of Art 50 compliance
- Commission guidelines on Art 50 transparency obligations
  - digital-strategy.ec.europa.eu/en/policies/guidelines-transparency-ai-generated-content
- GPAI Code of Practice, chapters Transparency, Copyright, Safety and Security
  - digital-strategy.ec.europa.eu/en/policies/contents-code-gpai
  - with the Art 53(1)(d) training data summary template and the GPAI guidelines
- Commission guidelines on prohibited practices and on the AI system definition
  - digital-strategy.ec.europa.eu/en/policies/regulatory-framework-ai
- EDPB guidelines and opinions, in particular Opinion 28/2024 on AI models
  - edpb.europa.eu
- BSI TR-03183, the profile a bill of materials is scored against
  - bsi.bund.de
- CJEU judgments, through `eurlex case-law <celex>` or curia.europa.eu

## Angles

Cover every angle below, grouping angles that read the same material into one agent.
Skip an angle whose subject the target does not contain, and say so.

- Data protection: the privacy policy, records of processing, and the code against DSGVO and BDSG.
  Every purpose needs a legal basis under Art 6, every processor a contract under Art 28, every transfer a basis under Chapter V, and the rights of Art 15 to 22 an implementation.
  Personal data in logs, telemetry, or fixtures is a finding.
- AI obligations: the system classified under the KI-VO against Art 5, the Annex III high-risk triggers, the Art 50 transparency duties, and the GPAI duties in Chapter V.
  State which application date binds, since the regulation phases in.
  The Art 53(1)(c) copyright policy rests on the mining opt-out of DSM Art 4 and UrhG 44b, so say whether the source reserved it.
- Product cybersecurity: the CRA and NIS2 documents, meaning the declaration of conformity, CE marking, Annex VII technical documentation, and the Art 14 reporting path.
  Read the `my-security` findings as evidence for or against conformity.
- Contract terms: terms of service and AGB against BGB 305 to 310 and UWG.
  German AGB law allows no reduction to the permissible extent, so a clause survives only if the invalid part can be struck without rewriting the rest.
  Check liability caps, unilateral change rights, and choice of law or venue in consumer contracts.
- Publication duties: the Impressum under DDG 5, website and app disclosures, accessibility under the Barrierefreiheits-RL, and trademark and naming use.
  A product claim the product does not keep is a UWG finding.
- Handed-over questions: what `my-license` could not settle, meaning protectability under UrhG 69a, authorship and employment under 69b, and whether a technique performs an act PatG 9 reserves.
  Answer each from the norm, naming the evidence the other skill supplied.

## Output

Each finding names the file and line, states the issue in one sentence, and gives the norm with its article, the evidence, and the remedy.
Rank by exposure with publication or release blockers first.
Close with every norm that could not be fetched, every command and angle that did not run, and a note that this is a review aid and not legal advice.
