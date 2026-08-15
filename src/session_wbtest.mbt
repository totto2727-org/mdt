///|
test "parse_agent 1 - accepts Codex and OpenCode" {
  assert_true(parse_agent("codex") is Codex)
  assert_true(parse_agent("opencode") is OpenCode)
}

///|
test "panic_parse_agent 2 - rejects an unsupported agent" {
  try! (parse_agent("other") |> ignore)
}

///|
test "translation_opencode_config 1 - denies every tool" {
  json_inspect(Json::object(translation_opencode_config()), content={
    "permission": "deny",
  })
}

///|
priv struct FakeTranslationCli {
  executable : @path.Path
  records : String
}

///|
async fn write_fake_executable(
  executable : @path.Path,
  script : String,
) -> Unit {
  let (exit_code, _, stderr) = @process.collect_output("/bin/sh", [
    "-c",
    "printf '%s' \"$1\" > \"$2\" && chmod 755 \"$2\"",
    "fixture-writer",
    script,
    executable.to_string(),
  ])
  if exit_code != 0 {
    fail("failed to create fake CLI: \{stderr.text()}")
  }
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
  write_fake_executable(executable, script)
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
      options=@opencode.ClientOptions::ClientOptions(
        executable_path_override=fixture.executable,
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
  write_fake_executable(executable, script)
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
async test "translate_markdown_with_client 2 - passes the selected Codex model" {
  with_fake_codex_cli(async fn(fixture) {
    let environment : Map[String, String] = {
      "PATH": "/usr/bin:/bin",
      "MDT_CODEX_RECORDS": fixture.records,
    }
    let client = @agent_codex.codex_cli(
      options=@codex.ClientOptions::ClientOptions(
        executable_path_override=fixture.executable,
        env=environment,
      ),
      thread_options=translation_codex_thread_options(Some("gpt-5.2-codex")),
    )
    let translated = translate_markdown_with_client(client, "ja", "# Hello")
    inspect(translated, content="# こんにちは")
    let args = fixture.read("args")
    assert_true(args.contains("exec\n--experimental-json\n"))
    assert_true(args.contains("--model\ngpt-5.2-codex\n"))
    assert_true(args.contains("--sandbox\nread-only\n"))
    assert_true(args.contains("--skip-git-repo-check\n"))
    assert_true(args.contains("approval_policy=\"never\"\n"))
  })
}

///|
async test "translate_markdown_with_client 3 - defaults Codex to GPT-5.6 Luna" {
  with_fake_codex_cli(async fn(fixture) {
    let environment : Map[String, String] = {
      "PATH": "/usr/bin:/bin",
      "MDT_CODEX_RECORDS": fixture.records,
    }
    let client = @agent_codex.codex_cli(
      options=@codex.ClientOptions::ClientOptions(
        executable_path_override=fixture.executable,
        env=environment,
      ),
      thread_options=translation_codex_thread_options(None),
    )
    translate_markdown_with_client(client, "ja", "# Hello") |> ignore
    assert_true(fixture.read("args").contains("--model\ngpt-5.6-luna\n"))
  })
}
