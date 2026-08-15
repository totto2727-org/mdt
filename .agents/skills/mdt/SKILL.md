---
name: mdt
description: Translate Markdown files to sibling language files or standard output using the selected OpenCode or Codex CLI through agent-sdk. Use when localizing README.md, AGENTS.md, docs, or other Markdown while preserving code blocks, fences, and frontmatter.
allowed-tools: Bash(mdt:*)
---

# `mdt` — Markdown translator

Uses the provider-neutral `agent-sdk` contract with an OpenCode or Codex adapter to translate Markdown files. It is designed for doc localization where code fences, links, frontmatter, and tables must remain intact.

## Usage

```bash
mdt <file>... --lang <code> [--agent <opencode|codex>] [--model <model>] [--force] [--format <file|stdio>]
```

- `<file>...` — one or more source Markdown paths; multiple files are translated up to four at a time in `file` format.
- `--lang, -l` — required. Target language code (e.g. `ja`, `ja-JP`, `en`); `MDT_LANG` provides the environment value.
- `--agent` — optional. Selects `opencode` or `codex`; `MDT_AGENT` provides the environment value. Defaults to `opencode`.
- `--model, -m` — optional. OpenCode accepts `provider/model`; Codex accepts a model ID. `MDT_MODEL` provides the environment value. Defaults to `opencode-go/deepseek-v4-flash` for OpenCode and `gpt-5.6-luna` for Codex.
- `--force, -f` — overwrite an existing output file; `MDT_FORCE` provides the boolean environment value.
- `--format` — selects sibling file output (`file`) or raw Markdown on standard output (`stdio`); `MDT_FORMAT` provides the environment value and the default is `file`.

Command-line options override environment variables, which override the defaults.

## Output filename convention

`mdt` writes a sibling file next to the source. For example:

- `README.md` + `--lang ja` → `README.ja.md`
- `AGENTS.md` + `--lang en` → `AGENTS.en.md`

Re-running without `--force` errors out if the target already exists (so you can re-translate selectively).

## Typical flows

```bash
# Localize the project README to Japanese
mdt --lang ja README.md

# Re-translate after upstream changes
mdt --lang ja --force README.md

# Translate with Codex and its default GPT-5.6 Luna model
mdt --lang en --agent codex docs/AGENTS.md

# Pin an OpenCode model
MDT_AGENT=opencode mdt --lang en --model anthropic/claude-sonnet-4-6 docs/AGENTS.md

# Translate multiple files concurrently
mdt --lang ja README.md docs/guide.md

# Pipe one translated document to another command
mdt --lang ja --format stdio README.md > README.ja.md
```

## Prerequisites

- The selected `opencode` or `codex` CLI must be installed and authenticated locally.
- The chosen model must be available to the selected provider.

## Limits

- `stdio` format accepts exactly one input file and emits the final raw Markdown after the provider completes.
- Each whole file is sent in one prompt, so it must fit within the selected model's context window.
