///|
enum Agent {
  Codex
  OpenCode
}

///|
fn parse_agent(raw : String) -> Agent raise {
  match raw {
    "codex" => Codex
    "opencode" => OpenCode
    _ => fail("unsupported agent: \{raw}; expected codex or opencode")
  }
}

///|
fn translation_opencode_config() -> @opencode.ConfigObject {
  { "permission": Json::string("deny") }
}

///|
fn translation_opencode_thread_options(
  model : String?,
) -> @opencode.ThreadOptions {
  @opencode.ThreadOptions::ThreadOptions(
    model=model.unwrap_or("opencode-go/deepseek-v4-flash"),
    title="mdt-translate",
  )
}

///|
fn translation_codex_thread_options(model : String?) -> @codex.ThreadOptions {
  @codex.ThreadOptions::ThreadOptions(
    model=model.unwrap_or("gpt-5.6-luna"),
    sandbox_mode=@codex.ReadOnly,
    skip_git_repo_check=true,
    approval_policy=@codex.Never,
  )
}

///|
fn translation_system_prompt(lang : String) -> String {
  [
    "You are a markdown translator. Translate the user's input markdown to \{lang}.",
    "Strict rules:",
    "- Preserve all code blocks, inline code, links, HTML tags, and YAML/TOML frontmatter exactly as-is (do not translate code, URLs, fence languages, or attribute values).",
    "- Translate prose in headings, paragraphs, lists, blockquotes, and table cells.",
    "- Keep the original markdown structure (heading levels, list markers, blank lines).",
    "- Output ONLY the translated markdown. No commentary, no explanation, no fence wrapping.",
  ].join("\n")
}

///|
fn translation_prompt(lang : String, text : String) -> String {
  [translation_system_prompt(lang), "", "Input markdown:", text].join("\n")
}

///|
async fn translate_markdown_with_client(
  client : @agent.Cli,
  lang : String,
  text : String,
) -> String {
  client.start().prompt(@agent.Prompt::Prompt(translation_prompt(lang, text))).text
}

///|
async fn translate_markdown(
  agent : Agent,
  lang : String,
  model : String?,
  text : String,
) -> String {
  match agent {
    Codex => {
      let client = @agent_codex.codex_cli(
        thread_options=translation_codex_thread_options(model),
      )
      translate_markdown_with_client(client, lang, text)
    }
    OpenCode => {
      let client = @agent_opencode.opencode_cli(
        options=@opencode.ClientOptions::ClientOptions(
          config=translation_opencode_config(),
        ),
        thread_options=translation_opencode_thread_options(model),
      )
      translate_markdown_with_client(client, lang, text)
    }
  }
}
