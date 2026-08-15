///|
async fn main {
  let app = @admiral.CliApp::CliApp(
    name="mdt",
    version="0.1.8",
    description="Translate a Markdown file via OpenCode or Codex",
    options=[
      translate_lang_option, translate_agent_option, translate_model_option, translate_force_option,
    ],
    positionals=[translate_file_argument],
    run=Some(run_translate),
  )
  app.run()
}
