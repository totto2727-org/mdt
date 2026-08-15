///|
let translate_files_argument : @admiral.PositionDef[Array[String]] = @admiral.position_strings(
  "files",
  description="Markdown files to translate",
  required=true,
)

///|
let translate_lang_option : @admiral.OptionDef[String] = @admiral.string(
  "lang",
  short='l',
  description="Target language code (for example, ja or ja-JP)",
  env="MDT_LANG",
  required=true,
)

///|
let translate_model_option : @admiral.OptionDef[String] = @admiral.string(
  "model",
  short='m',
  description="OpenCode provider/model (default: opencode-go/deepseek-v4-flash) or Codex model ID (default: gpt-5.6-luna)",
  env="MDT_MODEL",
)

///|
let translate_agent_option : @admiral.OptionDef[String] = @admiral.string(
  "agent",
  description="Agent CLI: opencode or codex",
  env="MDT_AGENT",
  default=Some("opencode"),
)

///|
let translate_force_option : @admiral.OptionDef[Bool] = @admiral.bool(
  "force",
  short='f',
  description="Overwrite an existing output file",
  env="MDT_FORCE",
)

///|
let translate_format_option : @admiral.OptionDef[String] = @admiral.string(
  "format",
  description="Output format: file or stdio",
  env="MDT_FORMAT",
  default=Some("file"),
)

///|
enum OutputFormat {
  File
  Stdio
} derive(Debug, Eq)

///|
fn parse_output_format(raw : String) -> OutputFormat raise {
  match raw {
    "file" => File
    "stdio" => Stdio
    _ => fail("unsupported format: \{raw}; expected file or stdio")
  }
}

///|
struct TranslateOptions {
  files : ReadOnlyArray[@path.Path]
  lang : String
  agent : Agent
  model : String?
  force : Bool
  format : OutputFormat
}

///|
fn translate_options(context : @admiral.Context) -> TranslateOptions raise {
  {
    files: context.get_strings_required(translate_files_argument).all.map(file => {
      @path.Path(file)
    }),
    lang: normalize_locale(context.get_string_required(translate_lang_option)),
    agent: parse_agent(context.get_string_required(translate_agent_option)),
    model: context.get_string(translate_model_option),
    force: context.get_bool(translate_force_option),
    format: parse_output_format(
      context.get_string_required(translate_format_option),
    ),
  }
}

///|
async fn run_translate(context : @admiral.Context) -> Unit {
  let options = translate_options(context)
  match options.format {
    Stdio => run_translate_stdio(options)
    File => run_translate_files(options)
  }
}

///|
async fn translate_file(
  options : TranslateOptions,
  file : @path.Path,
) -> String {
  let input = @fs.read_file(file.to_string()).text()
  translate_markdown(options.agent, options.lang, options.model, input)
}

///|
async fn run_translate_stdio(options : TranslateOptions) -> Unit {
  guard options.files is [file] else {
    fail("--format stdio requires exactly one input file")
  }
  @stdio.stdout.write(translate_file(options, file))
}

///|
async fn ensure_outputs_available(options : TranslateOptions) -> Unit {
  let outputs : Set[String] = Set([])
  for file in options.files {
    let output_text = target_path(file, options.lang).to_string()
    guard !outputs.contains(output_text) else {
      fail("multiple input files resolve to the same output: \{output_text}")
    }
    outputs.add(output_text)
    if !options.force {
      guard !@fs.exists(output_text) else {
        fail("output file already exists: \{output_text}")
      }
    }
  }
}

///|
async fn translate_file_to_output(
  options : TranslateOptions,
  file : @path.Path,
) -> Unit {
  let output_text = target_path(file, options.lang).to_string()
  let translated = translate_file(options, file)
  @fs.write_file(output_text, translated, create_mode=CreateOrTruncate)
  println("Written to \{output_text}")
}

///|
async fn run_translate_files(options : TranslateOptions) -> Unit {
  ensure_outputs_available(options)
  @async.all(
    options.files.map(file => () => translate_file_to_output(options, file)),
    max_concurrent=4,
  )
  |> ignore
}
