///|
async fn capture_translate_selection(
  argv : Array[String],
  env : Map[String, String],
) -> (String, String?) {
  let agent = Ref("")
  let model : Ref[String?] = Ref(None)
  let app = @admiral.CliApp::CliApp(
    name="mdt-test",
    options=[
      translate_lang_option, translate_agent_option, translate_model_option, translate_force_option,
    ],
    positionals=[translate_file_argument],
    run=Some(context => {
      let options = translate_options(context)
      agent.val = match options.agent {
        Codex => "codex"
        OpenCode => "opencode"
      }
      model.val = options.model
    }),
  )
  app.run(argv=Some(argv), env~)
  (agent.val, model.val)
}

///|
async test "translate options - applies CLI, environment, and default precedence" {
  let (default_agent, default_model) = capture_translate_selection(
    ["README.md", "--lang", "ja"],
    Map([]),
  )
  inspect(default_agent, content="opencode")
  assert_true(default_model is None)

  let (env_agent, env_model) = capture_translate_selection(
    ["README.md", "--lang", "ja"],
    { "MDT_AGENT": "codex", "MDT_MODEL": "luna" },
  )
  inspect(env_agent, content="codex")
  match env_model {
    Some(model) => inspect(model, content="luna")
    None => fail("expected MDT_MODEL")
  }

  let (argv_agent, argv_model) = capture_translate_selection(
    [
      "README.md", "--lang", "ja", "--agent", "opencode", "--model", "opencode-go/deepseek-v4-flash",
    ],
    { "MDT_AGENT": "codex", "MDT_MODEL": "luna" },
  )
  inspect(argv_agent, content="opencode")
  match argv_model {
    Some(model) => inspect(model, content="opencode-go/deepseek-v4-flash")
    None => fail("expected --model")
  }
}
