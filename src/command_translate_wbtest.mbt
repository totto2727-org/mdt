///|
async test "translate_options 1 - applies defaults" {
  let default_options = capture_translate_options(
    ["README.md", "--lang", "ja"],
    Map([]),
  )
  inspect(default_options, content="README.md|ja|opencode|none|false|file")
}

///|
async fn capture_translate_options(
  argv : Array[String],
  env : Map[String, String],
) -> String {
  let captured = Ref("")
  let app = @admiral.CliApp::CliApp(
    name="mdt-test",
    options=[
      translate_lang_option, translate_agent_option, translate_model_option, translate_force_option,
      translate_format_option,
    ],
    positionals=[translate_files_argument],
    run=Some(context => {
      let options = translate_options(context)
      let agent = match options.agent {
        Codex => "codex"
        OpenCode => "opencode"
      }
      let format = match options.format {
        File => "file"
        Stdio => "stdio"
      }
      captured.val = [
        options.files.iter().map(file => file.to_string()).join(","),
        options.lang,
        agent,
        options.model.unwrap_or("none"),
        options.force.to_string(),
        format,
      ].join("|")
    }),
  )
  app.run(argv=Some(argv), env~)
  captured.val
}

///|
async test "translate_options 2 - accepts every environment value" {
  let captured = capture_translate_options(["README.md", "docs/guide.md"], {
    "MDT_LANG": "JA-jp",
    "MDT_AGENT": "codex",
    "MDT_MODEL": "luna",
    "MDT_FORCE": "true",
    "MDT_FORMAT": "stdio",
  })
  inspect(
    captured,
    content="README.md,docs/guide.md|ja-jp|codex|luna|true|stdio",
  )
}

///|
async test "translate_options 3 - prefers CLI values over environment values" {
  let captured = capture_translate_options(
    [
      "README.md", "--lang", "en", "--agent", "opencode", "--model", "opencode-go/deepseek-v4-flash",
      "--force", "--format", "file",
    ],
    {
      "MDT_LANG": "ja",
      "MDT_AGENT": "codex",
      "MDT_MODEL": "luna",
      "MDT_FORCE": "false",
      "MDT_FORMAT": "stdio",
    },
  )
  inspect(
    captured,
    content="README.md|en|opencode|opencode-go/deepseek-v4-flash|true|file",
  )
}

///|
test "parse_output_format 1 - accepts file" {
  debug_inspect(parse_output_format("file"), content="File")
}

///|
test "parse_output_format 2 - accepts stdio" {
  debug_inspect(parse_output_format("stdio"), content="Stdio")
}

///|
test "panic_parse_output_format 3 - rejects an unsupported format" {
  try! (parse_output_format("html") |> ignore)
}

///|
async test "panic_ensure_outputs_available - rejects inputs sharing an output path" {
  let options : TranslateOptions = {
    files: [@path.Path("guide.md"), @path.Path("guide.en.md")],
    lang: "ja",
    agent: OpenCode,
    model: None,
    force: true,
    format: File,
  }
  try! ensure_outputs_available(options)
}
