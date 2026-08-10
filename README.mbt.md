# mdt

A native MoonBit CLI that translates one Markdown file through the installed OpenCode or Codex CLI. It uses the provider-neutral `totto2727/agent-sdk/cli` contract with provider adapters, retains provider-native options only at the composition root, reuses existing authentication, and denies every OpenCode tool through `OPENCODE_CONFIG_CONTENT`.

## Usage

```bash
mdt <file> --lang <code> [--provider <opencode|codex>] [--model <provider/model>] [--force]
```

| Flag | Alias | Description | Default |
| --- | --- | --- | --- |
| `--lang` | `-l` | Target language code, such as `ja` or `ja-JP` | required |
| `--provider` | | Agent provider: `opencode` or `codex` | `opencode` |
| `--model` | `-m` | Model in `provider/model` format | OpenCode: `opencode-go/deepseek-v4-flash`; Codex: CLI default |
| `--force` | `-f` | Overwrite an existing output file | off |

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

1. Admiral parses the input path and options into typed command data.
2. The CLI refuses to overwrite an existing output before starting the selected provider unless `--force` is present.
3. `totto2727/agent-sdk/cli` sends the common translation prompt to the selected provider adapter.
4. The OpenCode adapter starts `opencode run --format json` with the selected `provider/model` and sends a deny-all permission configuration through `OPENCODE_CONFIG_CONTENT`.
5. The Codex adapter maps the existing `provider/model` selection to the Codex model ID and applies `approval_policy=never`, `--sandbox read-only`, and `--skip-git-repo-check`.
6. Provider JSONL text events are joined by the adapter and written to the resolved output path.

The CLI sends the whole file in one prompt. A file larger than the selected model's context window is not chunked.
