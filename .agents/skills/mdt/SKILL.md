---
name: mdt
description: Translate a Markdown file to a sibling language file using the selected OpenCode or Codex CLI through agent-sdk. Use when localizing README.md, AGENTS.md, docs, or other Markdown while preserving code blocks, fences, and frontmatter.
allowed-tools: Bash(mdt:*)
---

# `mdt` — Markdown translator

Uses the provider-neutral `agent-sdk` contract with an OpenCode or Codex adapter to translate a single Markdown file. It is designed for doc localization where code fences, links, frontmatter, and tables must remain intact.

## Usage

```bash
mdt <file> --lang <code> [--agent <opencode|codex>] [--model <model>] [--force]
```

- `<file>` — path to the source Markdown.
- `--lang, -l` — required. Target language code (e.g. `ja`, `ja-JP`, `en`).
- `--agent` — optional. Selects `opencode` or `codex`; `MDT_AGENT` provides the environment value. Defaults to `opencode`.
- `--model, -m` — optional. OpenCode accepts `provider/model`; Codex accepts a model ID. `MDT_MODEL` provides the environment value. OpenCode defaults to `opencode-go/deepseek-v4-flash`; Codex uses the Codex CLI selection.
- `--force, -f` — overwrite an existing output file.

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

# Translate with Codex and its configured or recommended model
mdt --lang en --agent codex docs/AGENTS.md

# Pin an OpenCode model
MDT_AGENT=opencode mdt --lang en --model anthropic/claude-sonnet-4-6 docs/AGENTS.md
```

## Prerequisites

- The selected `opencode` or `codex` CLI must be installed and authenticated locally.
- The chosen model must be available to the selected provider.

## Limits

- One file per invocation. For batch use, drive `mdt` from a shell loop or `xargs`.
- The whole file is sent in one prompt, so it must fit within the selected model's context window.
