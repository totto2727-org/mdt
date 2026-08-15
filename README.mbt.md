# mdt

A native MoonBit CLI that translates Markdown files through the installed OpenCode or Codex CLI. It uses the provider-neutral `totto2727/agent-sdk/cli` contract with provider adapters, retains provider-native options only at the composition root, reuses existing authentication, and denies every OpenCode tool through `OPENCODE_CONFIG_CONTENT`.

## Usage

```bash
mdt <file>... --lang <code> [--agent <opencode|codex>] [--model <model>] [--force] [--format <file|stdio>]
```

| Flag | Environment | Description | Default |
| --- | --- | --- | --- |
| `--lang`, `-l` | `MDT_LANG` | Target language code, such as `ja` or `ja-JP` | required |
| `--agent` | `MDT_AGENT` | Agent CLI: `opencode` or `codex` | `opencode` |
| `--model`, `-m` | `MDT_MODEL` | OpenCode `provider/model` or Codex model ID | OpenCode: `opencode-go/deepseek-v4-flash`; Codex: `gpt-5.6-luna` |
| `--force`, `-f` | `MDT_FORCE` | Overwrite an existing output file | off |
| `--format` | `MDT_FORMAT` | Write sibling files (`file`) or raw Markdown to standard output (`stdio`) | `file` |

Command-line options override environment variables, which override the defaults.

Pass multiple input files to translate up to four at a time in `file` format:

```bash
mdt README.md docs/guide.md --lang ja
```

Use `stdio` format with exactly one input file to write only the translated Markdown to standard output:

```bash
mdt README.md --lang ja --format stdio > README.ja.md
```

The output is written beside the input with the normalized language tag before its extension. Existing language tags are replaced, and compound `.mbt.md` extensions are preserved.

```text
README.md         -> README.ja.md
guide.en.md       -> guide.ja.md
module.mbt.md     -> module.ja.mbt.md
module.en.mbt.md  -> module.ja.mbt.md
```

## Development

Enter the Nix development shell, then validate the package:

```bash
nix develop
moon check
moon test
moon package --list
```

Build the installable package with `nix build .#mdt`.

## How it works

1. Admiral parses the input paths and options into typed command data.
2. In `file` format, the CLI refuses to overwrite any existing output before starting a provider unless `--force` is present, then translates up to four inputs concurrently.
3. `totto2727/agent-sdk/cli` sends the common translation prompt to the selected provider adapter.
4. The OpenCode adapter starts `opencode run --format json` with the selected `provider/model` and sends a deny-all permission configuration through `OPENCODE_CONFIG_CONTENT`.
5. The Codex adapter passes the selected model ID, defaults to `gpt-5.6-luna`, and applies `approval_policy=never`, `--sandbox read-only`, and `--skip-git-repo-check`.
6. Provider JSONL text events are joined by the adapter and written either to each resolved output path or, for a single `stdio` input, to standard output.

The CLI sends the whole file in one prompt. A file larger than the selected model's context window is not chunked.
