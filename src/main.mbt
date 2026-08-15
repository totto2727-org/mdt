///|
async fn main {
  let app = @admiral.CliApp::CliApp(
    name="mdt",
    version="0.1.10",
    description="Translate Markdown files via OpenCode or Codex",
    options=[
      translate_lang_option, translate_agent_option, translate_model_option, translate_force_option,
      translate_format_option,
    ],
    positionals=[translate_files_argument],
    run=Some(run_translate),
  )
  app.run()
}
