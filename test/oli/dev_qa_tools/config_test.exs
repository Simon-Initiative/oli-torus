defmodule Oli.DevQATools.ConfigTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Oli.DevQATools.Config
  alias Swoosh.Adapters.Local.Storage.Memory

  describe "enabled?/2" do
    test "requires both a preview build and the exact case-insensitive true value" do
      for value <- ["true", "TRUE", "True", "tRuE"] do
        assert Config.enabled?(true, value)
      end

      for value <- [nil, "", " ", " true", "true ", "false", "1", "yes", "preview"] do
        refute Config.enabled?(true, value)
      end

      refute Config.enabled?(false, "true")
      refute Config.enabled?(false, "TRUE")
    end

    test "cannot be enabled by unrelated runtime state" do
      original_values =
        Map.new(
          ["HOST", "DEV_QA_SEED_PROFILE", "ENABLE_PLAYWRIGHT_SCENARIOS"],
          &{&1, System.get_env(&1)}
        )

      on_exit(fn ->
        Enum.each(original_values, fn {key, value} -> restore_env(key, value) end)
      end)

      System.put_env("HOST", "preview-123.example.test")
      System.put_env("DEV_QA_SEED_PROFILE", "review_demo")
      System.put_env("ENABLE_PLAYWRIGHT_SCENARIOS", "true")

      refute Config.enabled?(true, nil)
    end

    test "the test artifact cannot be activated at runtime" do
      original = System.get_env("DEV_QA_TOOLS_ENABLED")
      on_exit(fn -> restore_env("DEV_QA_TOOLS_ENABLED", original) end)
      System.put_env("DEV_QA_TOOLS_ENABLED", "true")

      refute Config.preview_build?()
      refute Config.enabled?()
    end
  end

  describe "log_startup_status/2" do
    test "emits one bounded warning for a disabled preview build" do
      log = capture_log(fn -> assert :ok = Config.log_startup_status(true, nil) end)

      assert log =~ "Preview QA tools are disabled"
      assert log =~ "DEV_QA_TOOLS_ENABLED=true"
      assert length(Regex.scan(~r/Preview QA tools are disabled/, log)) == 1
      assert byte_size(log) < 512
    end

    test "emits one bounded signal for an enabled preview build" do
      log = capture_log(fn -> assert :ok = Config.log_startup_status(true, "TRUE") end)

      assert log =~ "Preview QA tools are enabled"
      assert length(Regex.scan(~r/Preview QA tools are enabled/, log)) == 1
      assert byte_size(log) < 512
    end

    test "emits no signal for other build environments" do
      assert capture_log(fn -> assert :ok = Config.log_startup_status(false, "true") end) == ""
      assert capture_log(fn -> assert :ok = Config.log_startup_status(false, nil) end) == ""
    end
  end

  test "preview configuration always captures mail locally independent of runtime activation" do
    preview_config = Elixir.Config.Reader.read!("config/preview.exs")
    mailer_config = get_in(preview_config, [:oli, Oli.Mailer])

    assert mailer_config[:adapter] == Swoosh.Adapters.Local
    assert get_in(preview_config, [:oli, :dev_qa_tools, :preview_build?])

    for runtime_value <- [nil, "true"] do
      Memory.delete_all()

      email =
        Swoosh.Email.new()
        |> Swoosh.Email.from({"Torus", "no-reply@example.test"})
        |> Swoosh.Email.to("qa@example.test")
        |> Swoosh.Email.subject("Preview containment")
        |> Swoosh.Email.text_body("Captured locally")

      assert {:ok, %{id: message_id}} = Oli.Mailer.deliver(email, mailer_config)
      assert [%Swoosh.Email{headers: %{"Message-ID" => ^message_id}}] = Memory.all()
      assert Config.enabled?(true, runtime_value) == (runtime_value == "true")
    end
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
