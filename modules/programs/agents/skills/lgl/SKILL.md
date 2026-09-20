---
name: lgl
description: |
  Reviews documents and source code against German and EU law, covering data protection, the AI Act, the Cyber Resilience Act, contract terms, and copyright.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks for a legal or regulatory compliance review.
---

Review the target for legal compliance, over prose documents and over the code that implements what they promise.
Every finding cites the norm it rests on, fetched from an official source in this session.
A citation you did not fetch is a finding you must not make.

## Scope

The argument names the target and defaults to uncommitted changes: read a commit, a range, a branch or a pull request as a diff, and a path or the whole tree as raw files.
Documents (`md`, `typ`, `tex`, `rst`, `txt`, `pdf`) and source carry different obligations, so treat them as two sets.
Markup can hide a clause, so read documents as text with `pandoc`, and render with `typst compile` or `latexmk` where the output differs.
A norm several angles rest on is worth fetching once and sharing, rather than each agent retrieving it again.

## Tools

These are installed.
Decide per tool whether to run it yourself and pass the output on, or to name it in an agent's prompt and let the agent run it.
A norm several angles rest on is worth fetching once.
A scan only one angle reads is better delegated, since its output then never enters your context.

```sh
# eurlex: EU law, read from EUR-Lex and CELLAR
eurlex resolve "Regulation 2016/679"          # a human reference to a CELEX
eurlex get <celex> --lang DEU                 # the act as structured json, fetch DEU and ENG both
eurlex metadata <celex>                       # entry into force and the application dates
eurlex amendments <celex>                     # what has changed it
eurlex implementing <celex>                   # the delegated and implementing acts
eurlex case-law <celex>                       # the CJEU judgments interpreting it

# recht: German federal law, the consolidated text from gesetze-im-internet.de
recht list                                    # the catalogue, and how to confirm an abbreviation
recht list BGB                                # a table of contents
recht get BGB 823                             # one provision

# bearer: traces which personal data flows where, the evidence a finding needs
bearer scan .

# semgrep, ast-grep: logging, telemetry, retention and consent handling.
# semgrep reports pseudonymous metrics whenever a config pulls from its server, so keep the flag
semgrep --config auto --metrics=off
ast-grep run --pattern '<shape>' <path>

# kingfisher, gitleaks, trufflehog: personal data and credentials left in the history.
# without --no-validate kingfisher sends each candidate credential to its issuer, so ask first
kingfisher scan --no-validate .
gitleaks detect
trufflehog git file://.

# xh: downloads the guidance under Starting points, which carries no CELEX and no cli reaches
xh --download <url>

# pdftotext, pdftohtml, pdftoppm: reading a pdf
pdftotext -layout <pdf> -                                              # the text
pdftohtml -s -i -noframes -stdout <pdf> | pandoc -f html -t markdown   # the structure
pdftoppm -png -r 150 <pdf> page                                        # render a page to look at

# pandoc, typst, latexmk: a document as text, and rendered where the output differs
pandoc -t plain <file>
typst compile <file>
latexmk <file>

# lychee: citations and cross-references that no longer resolve
lychee .

# typos, harper-cli: the wording defects that change what a clause means
typos
harper-cli lint <file>

# the lcns skill owns licence detection and the compatibility verdict, so review what its
# findings mean in law rather than repeating them
```

## Starting points

Each entry gives the act and the identifier that fetches it.
These are pointers and not authority, so fetch before citing.
Confirm a German abbreviation with `recht list`, since the catalogue spelling is what resolves and it does not always match the URL.

### EU law, via `eurlex get <celex>`

- DSGVO, Regulation (EU) 2016/679
  - `32016R0679`
  - legal basis Art 6, processors Art 28, transfers Chapter V, rights Art 15 to 22
- KI-VO, Regulation (EU) 2024/1689
  - `32024R1689`
  - prohibited practices Art 5, high-risk Annex III, transparency Art 50, GPAI Chapter V
- Cyberresilienz-VO, Regulation (EU) 2024/2847
  - `32024R2847`
  - essential requirements Annex I, technical documentation Annex VII, reporting Art 14
- NIS2, Directive (EU) 2022/2555
  - `32022L2555`
  - risk management Art 21, reporting Art 23
- NIS2 implementing act, Commission Implementing Regulation (EU) 2024/2690
  - `32024R2690`
  - the technical requirements behind NIS2 Art 21
- Produkthaftungs-RL, Directive (EU) 2024/2853
  - `32024L2853`
  - software as a product, applying to what is placed on the market after 9 December 2026
- Data Act, Regulation (EU) 2023/2854
  - `32023R2854`
- DSA, Regulation (EU) 2022/2065
  - `32022R2065`
- ePrivacy-RL, Directive 2002/58/EC
  - `32002L0058`
  - Art 5(3) terminal equipment, which TDDDG 25 implements
- Cybersecurity Act, Regulation (EU) 2019/881
  - `32019R0881`
  - the certification schemes the CRA builds on
- DSM-Urheberrechts-RL, Directive (EU) 2019/790
  - `32019L0790`
  - Art 4 text and data mining, the opt-out an AI training claim turns on
- Barrierefreiheits-RL, Directive (EU) 2019/882
  - `32019L0882`

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
  - 44b text and data mining, 69a to 69g software
- UWG, Gesetz gegen den unlauteren Wettbewerb
- ProdHaftG, Produkthaftungsgesetz
  - until Directive (EU) 2024/2853 is transposed
- GeschGehG, Geschäftsgeheimnisgesetz

### Guidance, which neither cli reaches

These carry no CELEX, so fetch them with `xh` and read a pdf with `pdftotext -layout`.
They bind nobody, so cite the article they interpret and name the guidance as support.

- Code of Practice on Transparency of AI-generated Content, for KI-VO Art 50
  - digital-strategy.ec.europa.eu/en/policies/code-practice-ai-generated-content
  - the Commission confirmed it adequate, so adherence is evidence of Art 50 compliance
- Commission guidelines on Art 50 transparency obligations
  - digital-strategy.ec.europa.eu/en/policies/guidelines-transparency-ai-generated-content
- GPAI Code of Practice, chapters Transparency, Copyright, Safety and Security
  - digital-strategy.ec.europa.eu/en/policies/contents-code-gpai
  - with the Art 53(1)(d) training data summary template and the GPAI guidelines
- Commission guidelines on prohibited practices and on the AI system definition
  - digital-strategy.ec.europa.eu/en/policies/regulatory-framework-ai
- EDPB guidelines and opinions, in particular Opinion 28/2024 on AI models
  - edpb.europa.eu
- BSI TR-03183, the profile `sbomqs --bsi` scores against
  - bsi.bund.de
- CJEU judgments, through `eurlex case-law <celex>` or curia.europa.eu

## Angles

Cover every angle below.
How many agents that takes is yours to choose: give one agent several angles when they read the same material, since the cost is in reading it twice, not in the extra angle.
Skip an angle whose subject the target does not contain, and say which and why, so a quiet gap never reads as a clean run.

- Data protection: the privacy policy, records of processing and the code against DSGVO and BDSG.
  Every purpose needs a legal basis under Art 6, every processor a contract under Art 28, every transfer a basis under Chapter V, and the rights of Art 15 to 22 need something that implements them.
  Personal data in logs, telemetry or fixtures is a finding.
- AI obligations: the system classified under the KI-VO, against Art 5 prohibited practices, the Annex III high-risk triggers, the Art 50 transparency duties for generated content, and the GPAI duties in Chapter V.
  State which application date binds, since the regulation phases in.
- Product cybersecurity: the CRA and NIS2 duties that are documents rather than code, meaning the declaration of conformity, CE marking, Annex VII technical documentation and the Art 14 reporting path.
  The `scrty` skill owns the scanning.
- Contract terms: licences, terms of service and any AGB against BGB 305 to 310 and UWG.
  Apply the blue pencil test, since German AGB law allows no reduction to the permissible extent, so a clause survives only if the invalid part can be struck without rewriting the rest and a single overbroad limb voids the whole.
  Liability caps, unilateral change rights, and choice of law or venue a consumer contract cannot carry.
- Publication duties and IP: the Impressum under DDG 5, the disclosures a website or app owes, trademark and naming use, and authorship under UrhG.
  Third-party text, images or fonts with no licence to use them.

## Output

A finding names a file and line, states the issue in one sentence, and gives the norm with its article, the evidence in the repository, and the remedy.
Rank by exposure with anything that blocks publication or release first.
Then list every norm that could not be fetched, every command that did not run, and every angle that was skipped, and close by stating that this is a review aid and not legal advice.
