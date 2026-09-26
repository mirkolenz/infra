---
name: my-proofread
description: |
  Proofreads prose, comments, docstrings, user-facing strings, and identifiers for spelling, grammar, punctuation, and consistency mistakes in English and German, then reports the findings.
  The argument names the target and defaults to uncommitted changes.
  Use when the user asks to proofread, spell check, or grammar check.
---

Find the spelling and grammar mistakes in the target, and give the corrected text.
Checkers flag many words they merely do not know, so confirm every hit in context.

## Scope

A commit, range, branch, or pull request is diff mode, and a path or the whole tree is file mode.
In diff mode a touched sentence is in scope whole, and so are the commit messages.
Documents (`md`, `typ`, `tex`, `rst`, `txt`) are read whole, including their includes, which `typst compile --deps - <main.typ> $TMPDIR/out.pdf` lists for typst.
Source code is read only for its comments, docstrings, user-facing strings, and identifiers.
Split a long document by included file or chapter, give each part to exactly one agent, and say which parts nobody reached.

## Tools

These are installed.
Run each once over the whole target, and pass each agent only the hits in its part.
Judge a term flagged throughout once.

```sh
# typos: english identifiers and strings, skip it on german text
typos --format brief <path>

# harper-cli: english prose and comments, pass `-d british` for british text
harper-cli lint --format compact --quiet <files>

# codebook: german spelling, it understands typst, latex, and markdown
codebook-lsp lint --unique <files>
```

## Angles

Cover every angle below, grouping angles that read the same material into one agent.
Skip an angle whose subject the target does not contain, and say so.

- Spelling: typos, umlauts and `ß`, and misspelled identifiers with every place they are used.
  Technical terms, names, code spans, and URLs are not mistakes.
- Grammar: agreement, articles, cases, tense, missing or doubled words, and German comma rules.
  Checkers miss most grammar mistakes, so read the prose yourself.
- Consistency: one spelling per term, one dialect per document, and consistent capitalization and hyphenation.
- Conventions: the writing rules in AGENTS.md, naming the broken rule.

## Output

Each finding names the file and line, quotes the wrong text, and gives the correction.
Rank spelling and grammar above consistency, and merge a repeated mistake into one finding listing its places.
Close with the languages checked and the tools, angles, and parts skipped and why.
If a findings-reporting tool is available, call it once instead of printing them.
