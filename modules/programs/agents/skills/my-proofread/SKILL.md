---
name: my-proofread
description: |
  Proofreads prose, comments, docstrings, user-facing strings, and identifiers for spelling, grammar, punctuation, and consistency mistakes in English and German, then reports the findings.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks to proofread, spell check, or grammar check.
---

Find the spelling and grammar mistakes in the target, and give the corrected text.
Review for precision: a checker flags many words it merely does not know, so a finding is only a finding once you have read it in context.

## Scope

The argument names the target and defaults to uncommitted changes.
A commit, a range, a branch or a pull request is diff mode, and a path or the whole tree is file mode.
In diff mode a touched sentence is in scope whole, since the mistake may sit in an untouched word, and the commit messages of a range are in scope too.
Documents (`md`, `typ`, `tex`, `rst`, `txt`) are read whole, while source code contributes its comments, docstrings, user-facing strings, and identifiers.
A document is the files it is built from, so follow its includes, which `typst compile --deps - <main.typ> $TMPDIR/out.pdf` lists for typst.
Split along the document's own structure, an included file or a run of chapters per agent, give each part to exactly one agent, and say which parts nobody reached.
An agent reads its part by offset, so no context ever holds a long document whole.

## Tools

These are installed and take a whole book in seconds.
Run them once over the target and pass each agent only the hits inside its part.

```sh
# typos: misspelled identifiers, strings and file names in english, with few false positives.
# skip it on german text, where it misreads short words such as `ist` or `ein`
typos --format brief <path>

# harper-cli: english spelling and grammar in prose and in the comments of source code, the default.
# pass `-d british` for a british text. `--count` tallies the hits per word, so a term flagged
# throughout is judged once, then added to a dictionary passed with `-u`
harper-cli lint --format compact --quiet <files>
harper-cli lint --count --quiet --no-color <files>

# codebook: german spelling, since harper is english only. it parses typst, latex and markdown,
# so markup is not flagged. `--unique` lists each word once, and a term flagged throughout goes
# into `words` in a `codebook.toml` at the project root
codebook-lsp lint --unique <files>
codebook-lsp lint --suggest <files>
```

## Angles

Cover every angle below.
Skip an angle whose subject the target does not contain, and say which and why, so a quiet gap never reads as a clean run.

- Spelling: misspelled words, wrong umlauts or `ß`, and misspelled identifiers, naming every place a misspelled identifier is used.
  Technical terms, names, code spans, and URLs are not mistakes, so drop those hits.
- Grammar: agreement, articles, cases, tense, missing or doubled words, and German comma rules.
  No checker covers german grammar and harper misses many english mistakes, so read the prose yourself rather than trusting a clean run.
- Consistency: one spelling per term, one dialect per document, consistent capitalization and hyphenation of compounds.
- Conventions: the text against the writing rules in AGENTS.md, naming the rule that is broken.

## Output

A finding names a file and line, quotes the wrong text, and gives the correction.
Rank grammar and spelling above consistency, and group a repeated mistake into one finding listing its places.
Close with the tools and angles you skipped and why, and the languages you checked.
If a findings-reporting tool is available, call it once instead of printing them.
