///|
test "parse_model 1 - separates provider and model IDs" {
  let model = parse_model("anthropic/claude-sonnet-4-6")
  inspect(model.provider_id, content="anthropic")
  inspect(model.model_id, content="claude-sonnet-4-6")
}

///|
test "parse_provider 1 - accepts Codex and OpenCode" {
  assert_true(parse_provider("codex") is Codex)
  assert_true(parse_provider("opencode") is OpenCode)
}

///|
test "panic_parse_provider 2 - rejects an unsupported provider" {
  try! (parse_provider("other") |> ignore)
}

///|
test "panic_parse_model 2 - rejects a missing provider ID" {
  try! (parse_model("/claude-sonnet-4-6") |> ignore)
}

///|
test "panic_parse_model 3 - rejects a missing model ID" {
  try! (parse_model("anthropic/") |> ignore)
}

///|
test "ModelSelection to_string 1 - returns the CLI model ID" {
  inspect(
    parse_model("anthropic/claude-sonnet-4-6").to_string(),
    content="anthropic/claude-sonnet-4-6",
  )
}

///|
test "translation_opencode_config 1 - denies every tool" {
  match translation_opencode_config().get("permission") {
    Some(@opencode.ConfigString(value)) => inspect(value, content="deny")
    _ => fail("expected deny-all OpenCode configuration")
  }
}

///|
test "translation_prompt 1 - combines instructions and Markdown" {
  let prompt = translation_prompt("ja", "# Hello")
  assert_true(prompt.contains("Translate the user's input markdown to ja."))
  assert_true(prompt.contains("# Hello"))
  assert_true(prompt.contains("Output ONLY the translated markdown."))
}

///|
priv struct FakeTranslationCli {
  executable : @path.Path
  records : String
}

///|
async fn with_fake_translation_cli(
  run : async (FakeTranslationCli) -> Unit,
) -> Unit {
  let root = @fs.tmpdir(prefix="mdt-opencode-cli-test-")
  let executable = @path.Path(root) |> @path.Path::join(@path.Path("opencode"))
  let records = "\{root}/records"
  @fs.mkdir(records, recursive=true)
  let script =
    #|#!/bin/sh
    #|set -eu
    #|records="${MDT_OPENCODE_RECORDS:?}"
    #|printf '%s\n' "$@" > "$records/args"
    #|/bin/cat > "$records/stdin"
    #|/usr/bin/env | /usr/bin/sort > "$records/env"
    #|printf '%s\n' '{"type":"text","timestamp":1,"sessionID":"session-1","part":{"type":"text","text":"# こんにちは"}}'
    #|
  @fs.write_file(executable.to_string(), script, create_mode=CreateOrTruncate)
  @fs.chmod(executable.to_string(), 0o755)
  let fixture : FakeTranslationCli = { executable, records }
  run(fixture) catch {
    error => {
      @async.protect_from_cancel(async fn() { @fs.rmdir(root, recursive=true) })
      raise error
    }
  }
  @fs.rmdir(root, recursive=true)
}

///|
async fn FakeTranslationCli::read(
  self : FakeTranslationCli,
  name : String,
) -> String {
  @fs.read_file("\{self.records}/\{name}").text()
}

///|
async test "translate_markdown_with_client 1 - uses OpenCode CLI JSON mode" {
  with_fake_translation_cli(async fn(fixture) {
    let environment : Map[String, String] = {
      "PATH": "/usr/bin:/bin",
      "MDT_OPENCODE_RECORDS": fixture.records,
    }
    let client = @agent_opencode.opencode_cli(
      options=@opencode.OpenCodeOptions::OpenCodeOptions(
        opencode_path_override=fixture.executable,
        config=translation_opencode_config(),
        env=environment,
      ),
      thread_options=translation_opencode_thread_options(None),
    )
    let translated = translate_markdown_with_client(client, "ja", "# Hello")
    inspect(translated, content="# こんにちは")
    let args = fixture.read("args")
    assert_true(args.contains("run\n--format\njson\n"))
    assert_true(args.contains("--model\nopencode-go/deepseek-v4-flash\n"))
    let input = fixture.read("stdin")
    assert_true(input.contains("Translate the user's input markdown to ja."))
    assert_true(input.contains("# Hello"))
    let config_lines : Array[String] = fixture
      .read("env")
      .split("\n")
      .filter_map(line => {
        if line.has_prefix("OPENCODE_CONFIG_CONTENT=") {
          Some(line.to_owned())
        } else {
          None
        }
      })
      .collect()
    let config_line = config_lines.get(0).unwrap_or("")
    inspect(
      config_line,
      content="OPENCODE_CONFIG_CONTENT={\"permission\":\"deny\"}",
    )
  })
}

///|
priv struct FakeCodexCli {
  executable : @path.Path
  records : String
}

///|
async fn with_fake_codex_cli(run : async (FakeCodexCli) -> Unit) -> Unit {
  let root = @fs.tmpdir(prefix="mdt-codex-cli-test-")
  let executable = @path.Path(root) |> @path.Path::join(@path.Path("codex"))
  let records = "\{root}/records"
  @fs.mkdir(records, recursive=true)
  let script =
    #|#!/bin/sh
    #|set -eu
    #|records="${MDT_CODEX_RECORDS:?}"
    #|printf '%s\n' "$@" > "$records/args"
    #|/bin/cat > "$records/stdin"
    #|printf '%s\n' '{"type":"thread.started","thread_id":"thread-1"}'
    #|printf '%s\n' '{"type":"turn.started"}'
    #|printf '%s\n' '{"type":"item.completed","item":{"id":"item-1","type":"agent_message","text":"# こんにちは"}}'
    #|printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0}}'
    #|
  @fs.write_file(executable.to_string(), script, create_mode=CreateOrTruncate)
  @fs.chmod(executable.to_string(), 0o755)
  let fixture : FakeCodexCli = { executable, records }
  run(fixture) catch {
    error => {
      @async.protect_from_cancel(async fn() { @fs.rmdir(root, recursive=true) })
      raise error
    }
  }
  @fs.rmdir(root, recursive=true)
}

///|
async fn FakeCodexCli::read(self : FakeCodexCli, name : String) -> String {
  @fs.read_file("\{self.records}/\{name}").text()
}

///|
async test "translate_markdown_with_client 2 - maps the legacy provider model to Codex safely" {
  with_fake_codex_cli(async fn(fixture) {
    let environment : Map[String, String] = {
      "PATH": "/usr/bin:/bin",
      "MDT_CODEX_RECORDS": fixture.records,
    }
    let client = @agent_codex.codex_cli(
      options=@codex.CodexOptions::CodexOptions(
        codex_path_override=fixture.executable,
        env=environment,
      ),
      thread_options=translation_codex_thread_options(
        Some(parse_model("openai/gpt-5.2-codex")),
      ),
    )
    let translated = translate_markdown_with_client(client, "ja", "# Hello")
    inspect(translated, content="# こんにちは")
    let args = fixture.read("args")
    assert_true(args.contains("exec\n--experimental-json\n"))
    assert_true(args.contains("--model\ngpt-5.2-codex\n"))
    assert_true(args.contains("--sandbox\nread-only\n"))
    assert_true(args.contains("--skip-git-repo-check\n"))
    assert_true(args.contains("approval_policy=\"never\"\n"))
    let input = fixture.read("stdin")
    assert_true(input.contains("Translate the user's input markdown to ja."))
    assert_true(input.contains("# Hello"))
  })
}

///|
async test "translate_markdown_with_client 3 - lets Codex select its default model" {
  with_fake_codex_cli(async fn(fixture) {
    let environment : Map[String, String] = {
      "PATH": "/usr/bin:/bin",
      "MDT_CODEX_RECORDS": fixture.records,
    }
    let client = @agent_codex.codex_cli(
      options=@codex.CodexOptions::CodexOptions(
        codex_path_override=fixture.executable,
        env=environment,
      ),
      thread_options=translation_codex_thread_options(None),
    )
    translate_markdown_with_client(client, "ja", "# Hello") |> ignore
    assert_false(fixture.read("args").contains("--model\n"))
  })
}
