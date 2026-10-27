defmodule Oli.Playwright.ConfigTest do
  use ExUnit.Case, async: true

  test "standalone compile configuration contains capabilities and no runtime secrets" do
    config = Config.Reader.read!("config/playwright.exs")
    oli = Keyword.fetch!(config, :oli)
    assert oli[:env] == :playwright
    assert oli[:enable_playwright_scenarios]
    assert oli[:enable_e2e_mailbox]
    assert oli[:recaptcha_module] == Oli.Playwright.Recaptcha
    assert oli[Oli.Mailer][:adapter] == Swoosh.Adapters.Local
    refute oli[:preview_qa_tools]
    refute oli[:playwright_scenario_token]
    refute oli[:playwright_captcha_token]
    endpoint = oli[OliWeb.Endpoint]
    assert endpoint[:check_origin]
    refute endpoint[:debug_errors]
    refute endpoint[:code_reloader]
    refute endpoint[:watchers]
    refute endpoint[:live_reload]
    assert endpoint[:cache_static_manifest] == "priv/static/cache_manifest.json"
  end

  @tag timeout: 120_000
  test "runtime requires automation secrets, permits no private bucket and does not change compile selections" do
    script = ~S'''
    import ExUnit.Assertions
    require Logger
    Logger.configure(level: :error)

    System.put_env(%{
      "DATABASE_URL" => "postgresql://unused:unused@localhost/playwright",
      "SECRET_KEY_BASE" => String.duplicate("s", 64),
      "LIVE_VIEW_SALT" => "runtime-salt",
      "HOST" => "localhost",
      "S3_MEDIA_BUCKET_NAME" => "unused-media",
      "S3_XAPI_BUCKET_NAME" => "unused-xapi",
      "MEDIA_URL" => "http://localhost/media",
      "CLOAK_VAULT_KEY" => Base.encode64(:crypto.strong_rand_bytes(32))
    })
    System.delete_env("PLAYWRIGHT_ASSETS_BUCKET")
    System.delete_env("FORCE_SSL")
    System.delete_env("RECAPTCHA_SITE_KEY")
    System.delete_env("RECAPTCHA_PRIVATE_KEY")
    for absent <- [nil, ""] do
      case absent do
        nil -> System.delete_env("PLAYWRIGHT_SCENARIO_TOKEN")
        value -> System.put_env("PLAYWRIGHT_SCENARIO_TOKEN", value)
      end
      assert_raise RuntimeError, ~r/PLAYWRIGHT_SCENARIO_TOKEN must be set and nonempty/, fn ->
        Config.Reader.read!("config/runtime.exs", env: :playwright)
      end
    end
    System.put_env("PLAYWRIGHT_SCENARIO_TOKEN", "scenario-secret")
    for absent <- [nil, ""] do
      case absent do
        nil -> System.delete_env("PLAYWRIGHT_CAPTCHA_TOKEN")
        value -> System.put_env("PLAYWRIGHT_CAPTCHA_TOKEN", value)
      end
      assert_raise RuntimeError, ~r/PLAYWRIGHT_CAPTCHA_TOKEN must be set and nonempty/, fn ->
        Config.Reader.read!("config/runtime.exs", env: :playwright)
      end
    end
    System.put_env("PLAYWRIGHT_CAPTCHA_TOKEN", "captcha-secret")
    config = Config.Reader.read!("config/runtime.exs", env: :playwright)
    oli = config[:oli]
    assert oli[:playwright_scenario_token] == "scenario-secret"
    assert oli[:playwright_captcha_token] == "captcha-secret"
    refute oli[:recaptcha][:site_key]
    refute oli[:recaptcha][:secret]
    assert oli[:force_ssl_redirect?]
    refute oli[:playwright_assets_bucket]
    refute Keyword.has_key?(oli, :recaptcha_module)
    refute Keyword.has_key?(oli, :enable_playwright_scenarios)
    refute Keyword.has_key?(oli, :enable_e2e_mailbox)
    System.put_env("FORCE_SSL", "false")
    assert Config.Reader.read!("config/runtime.exs", env: :playwright)[:oli][:force_ssl_redirect?] == false
    '''

    run_isolated(script)
  end

  for env <- [:playwright, :prod] do
    @tag timeout: 120_000
    test "#{env} verifier selection is immutable after compilation" do
      script = ~S'''
      import ExUnit.Assertions
      [env] = System.argv()
      env = String.to_atom(env)
      config = Config.Reader.read!("config/#{env}.exs")[:oli]
      Application.put_env(:oli, :env, env)
      case config[:recaptcha_module] do
        nil -> Application.delete_env(:oli, :recaptcha_module)
        implementation -> Application.put_env(:oli, :recaptcha_module, implementation)
      end
      Code.compiler_options(ignore_module_conflict: true)
      Code.compile_file("lib/oli/recaptcha.ex")
      Application.put_env(:oli, :playwright_captcha_token, "captcha-secret")
      # Any unexpected Google invocation fails the Playwright checks locally.
      defmodule Oli.Utils.Recaptcha do
        def verify("production-response"), do: {:success, true}
        def verify(_), do: raise("normal verifier selected")
      end
      for runtime_env <- [:prod, :playwright] do
        Application.put_env(:oli, :env, runtime_env)
        Application.put_env(:oli, :recaptcha_module, Oli.Playwright.Recaptcha)
        case env do
          :playwright ->
            assert Oli.Recaptcha.verify("captcha-secret") == {:success, true}
            for value <- [nil, "", "invalid", %{}, 17] do
              assert Oli.Recaptcha.verify(value) == {:success, false}
            end
          :prod ->
            assert Oli.Recaptcha.verify("production-response") == {:success, true}
            assert_raise RuntimeError, "normal verifier selected", fn ->
              Oli.Recaptcha.verify(nil)
            end
        end
      end
      '''

      run_isolated(script, [Atom.to_string(unquote(env))])
    end
  end

  defp run_isolated(script, args \\ []) do
    paths = Enum.flat_map(:code.get_path(), fn path -> ["-pa", List.to_string(path)] end)

    {output, status} =
      System.cmd(System.find_executable("elixir"), paths ++ ["-e", script, "--"] ++ args,
        env: [{"ERL_FLAGS", "+S 2:2"}],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output == ""
  end
end
