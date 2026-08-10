///|
struct ModelSelection {
  provider_id : String
  model_id : String
}

///|
enum Provider {
  Codex
  OpenCode
}

///|
fn parse_provider(raw : String) -> Provider raise {
  match raw {
    "codex" => Codex
    "opencode" => OpenCode
    _ => fail("unsupported provider: \{raw}; expected codex or opencode")
  }
}

///|
fn parse_model(raw : String) -> ModelSelection raise {
  guard raw.find("/") is Some(slash) && slash > 0 && slash < raw.length() - 1 else {
    fail("invalid model format: \{raw}")
  }
  { provider_id: raw[:slash].to_owned(), model_id: raw[slash + 1:].to_owned() }
}

///|
fn ModelSelection::to_string(self : ModelSelection) -> String {
  "\{self.provider_id}/\{self.model_id}"
}

///|
fn translation_opencode_config() -> @opencode.OpenCodeConfigObject {
  { "permission": @opencode.ConfigString("deny") }
}

///|
fn translation_opencode_thread_options(
  model : ModelSelection?,
) -> @opencode.ThreadOptions {
  @opencode.ThreadOptions::ThreadOptions(
    model=model
      .map(fn(selection) { selection.to_string() })
      .unwrap_or("opencode-go/deepseek-v4-flash"),
    title="mdt-translate",
  )
}

///|
fn translation_codex_thread_options(
  model : ModelSelection?,
) -> @codex.ThreadOptions {
  @codex.ThreadOptions::ThreadOptions(
    model?=model.map(fn(selection) { selection.model_id }),
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
  provider : Provider,
  lang : String,
  model : ModelSelection?,
  text : String,
) -> String {
  match provider {
    Codex => {
      let client = @agent_codex.codex_cli(
        thread_options=translation_codex_thread_options(model),
      )
      translate_markdown_with_client(client, lang, text)
    }
    OpenCode => {
      let client = @agent_opencode.opencode_cli(
        options=@opencode.OpenCodeOptions::OpenCodeOptions(
          config=translation_opencode_config(),
        ),
        thread_options=translation_opencode_thread_options(model),
      )
      translate_markdown_with_client(client, lang, text)
    }
  }
}
