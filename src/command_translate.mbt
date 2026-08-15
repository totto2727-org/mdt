///|
let translate_file_argument : @admiral.PositionDef[String] = @admiral.position_string(
  "file",
  description="Markdown file to translate",
  required=true,
)

///|
let translate_lang_option : @admiral.OptionDef[String] = @admiral.string(
  "lang",
  short='l',
  description="Target language code (for example, ja or ja-JP)",
  required=true,
)

///|
let translate_model_option : @admiral.OptionDef[String] = @admiral.string(
  "model",
  short='m',
  description="OpenCode provider/model or Codex model ID",
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
)

///|
struct TranslateOptions {
  file : @path.Path
  lang : String
  agent : Agent
  model : String?
  force : Bool
}

///|
fn translate_options(context : @admiral.Context) -> TranslateOptions raise {
  {
    file: @path.Path(context.get_string_required(translate_file_argument)),
    lang: normalize_locale(context.get_string_required(translate_lang_option)),
    agent: parse_agent(context.get_string_required(translate_agent_option)),
    model: context.get_string(translate_model_option),
    force: context.get_bool(translate_force_option),
  }
}

///|
async fn run_translate(context : @admiral.Context) -> Unit {
  let options = translate_options(context)
  let output = target_path(options.file, options.lang)
  let output_text = output.to_string()
  guard options.force || !@fs.exists(output_text) else {
    fail("output file already exists: \{output_text}")
  }
  let input = @fs.read_file(options.file.to_string()).text()
  let translated = translate_markdown(
    options.agent,
    options.lang,
    options.model,
    input,
  )
  @fs.write_file(output_text, translated, create_mode=CreateOrTruncate)
  println("Written to \{output_text}")
}
