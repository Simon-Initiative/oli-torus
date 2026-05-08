# Manual verification script for MER-5257 Phase 1 (email_sending feature).
#
# Run from the repo root:
#
#   mix run scripts/dev/email_sending_phase_1_check.exs
#
# Optional flags via environment variables:
#
#   EMAIL_PHASE1_REAL_AI=1   — also exercise a real AI completion call
#                             (requires OPENAI_API_KEY or ANTHROPIC_API_KEY;
#                             costs a few API tokens; ~5-15 sec).
#
# What this script does:
#
#   1. Exercises Situation enum (chunk 1.1)
#   2. Exercises ContextBuilder + EmailContext validation (chunk 1.2)
#   3. Inspects the composed PromptComposer output (chunk 1.4)
#   4. Verifies DB rows seeded for :instructor_email (chunk 1.5)
#   5. Drives AIDraftFacade end-to-end with an injected fake AI response (chunk 1.3)
#   6. Demonstrates :telemetry events firing for :generated and :failed
#   7. (Optional) Calls the real AI provider end-to-end if EMAIL_PHASE1_REAL_AI=1
#
# Output: pass/fail counts at the end. Non-zero exit on any failure.

defmodule EmailPhase1Check do
  @moduledoc false

  alias Oli.GenAI.Completions.ServiceConfig
  alias Oli.GenAI.FeatureConfig

  alias Oli.InstructorDashboard.Email.{
    AIDraftFacade,
    ContextBuilder,
    EmailContext,
    PromptComposer,
    Situation
  }

  import Ecto.Query

  @bold IO.ANSI.bright()
  @reset IO.ANSI.reset()
  @green IO.ANSI.green()
  @red IO.ANSI.red()
  @yellow IO.ANSI.yellow()
  @cyan IO.ANSI.cyan()

  def run do
    state = %{passed: 0, failed: 0, failures: []}

    state =
      state
      |> section("1. Situation enum (chunk 1.1)", &test_situation/1)
      |> section("2. ContextBuilder + EmailContext (chunk 1.2)", &test_context_builder/1)
      |> section("3. PromptComposer (chunk 1.4)", &test_prompt_composer/1)
      |> section("4. DB rows for :instructor_email (chunk 1.5)", &test_db_rows/1)
      |> section("5. AIDraftFacade with mocked AI (chunk 1.3)", &test_facade_mocked/1)
      |> section("6. Telemetry events", &test_telemetry/1)
      |> maybe_real_ai()

    summary(state)
  end

  defp section(state, label, fun) do
    IO.puts("\n#{@bold}#{@cyan}══ #{label}#{@reset}")
    fun.(state)
  end

  defp pass(state, msg) do
    IO.puts("  #{@green}✓#{@reset} #{msg}")
    %{state | passed: state.passed + 1}
  end

  defp fail(state, msg, detail) do
    IO.puts("  #{@red}✗ #{msg}#{@reset}")
    IO.puts("    #{@red}#{detail}#{@reset}")
    %{state | failed: state.failed + 1, failures: [{msg, detail} | state.failures]}
  end

  defp expect(state, msg, fun) do
    case safe_call(fun) do
      :ok -> pass(state, msg)
      {:error, detail} -> fail(state, msg, detail)
    end
  end

  defp safe_call(fun) do
    try do
      case fun.() do
        true -> :ok
        :ok -> :ok
        {:ok, _} -> :ok
        false -> {:error, "predicate returned false"}
        other -> {:error, "unexpected return: #{inspect(other)}"}
      end
    rescue
      e -> {:error, "raised: #{Exception.message(e)}"}
    catch
      kind, reason -> {:error, "caught #{kind}: #{inspect(reason)}"}
    end
  end

  ## 1. Situation enum

  defp test_situation(state) do
    state
    |> expect("all_keys/0 returns a non-empty list", fn ->
      match?([_ | _], Situation.all_keys())
    end)
    |> expect("all_keys/0 includes :struggling_students", fn ->
      :struggling_students in Situation.all_keys()
    end)
    |> expect("description/1 returns a binary for every key", fn ->
      Enum.all?(Situation.all_keys(), fn k ->
        match?(s when is_binary(s) and s != "", Situation.description(k))
      end)
    end)
    |> expect("valid?/1 returns true for whitelisted keys", fn ->
      Enum.all?(Situation.all_keys(), &Situation.valid?/1)
    end)
    |> expect("valid?/1 returns false for unknown atoms", fn ->
      not Situation.valid?(:totally_made_up_key)
    end)
    |> expect("valid?/1 returns false for non-atom inputs", fn ->
      not Situation.valid?("string") and not Situation.valid?(42)
    end)
    |> expect("description/1 raises FunctionClauseError for unknown keys", fn ->
      try do
        Situation.description(:not_a_key)
        false
      rescue
        FunctionClauseError -> true
      end
    end)
  end

  ## 2. ContextBuilder

  defp test_context_builder(state) do
    valid_input = %{
      section_id: 1,
      course_title: "Test Course",
      scope_label: "Module 1",
      situation_key: :struggling_students,
      recipients: [
        %{
          student_id: 101,
          email: "alex@example.com",
          given_name: "Alex",
          family_name: "Kim"
        }
      ]
    }

    state
    |> expect("build/1 returns {:ok, %EmailContext{}} on valid input", fn ->
      match?({:ok, %EmailContext{}}, ContextBuilder.build(valid_input))
    end)
    |> expect("returned struct has expected default tone :neutral", fn ->
      {:ok, ctx} = ContextBuilder.build(valid_input)
      ctx.tone == :neutral
    end)
    |> expect("recipient_count is computed correctly", fn ->
      {:ok, ctx} = ContextBuilder.build(valid_input)
      ctx.recipient_count == 1
    end)
    |> expect("missing :section_id returns :missing_section_id", fn ->
      ContextBuilder.build(Map.delete(valid_input, :section_id)) ==
        {:error, :missing_section_id}
    end)
    |> expect("invalid :situation_key returns :invalid_situation_key", fn ->
      {:error, :invalid_situation_key} =
        ContextBuilder.build(%{valid_input | situation_key: :nope})

      true
    end)
    |> expect("empty :recipients returns :empty_recipients", fn ->
      {:error, :empty_recipients} = ContextBuilder.build(%{valid_input | recipients: []})
      true
    end)
    |> expect("recipient missing :email is rejected with index + key", fn ->
      bad = [%{student_id: 1, given_name: "X", family_name: "Y"}]

      {:error, {:invalid_recipient, 0, :email}} =
        ContextBuilder.build(%{valid_input | recipients: bad})

      true
    end)
    |> expect("invalid :tone returns :invalid_tone", fn ->
      {:error, :invalid_tone} = ContextBuilder.build(Map.put(valid_input, :tone, :angry))
      true
    end)
  end

  ## 3. PromptComposer

  defp test_prompt_composer(state) do
    {:ok, ctx} =
      ContextBuilder.build(%{
        section_id: 1,
        course_title: "Photosynthesis 101",
        scope_label: "Unit 2",
        situation_key: :inactive_students,
        tone: :encouraging,
        recipients: [
          %{
            student_id: 1,
            email: "a@example.com",
            given_name: "A",
            family_name: "B"
          }
        ]
      })

    [%{role: :system, content: prompt}] = PromptComposer.compose(ctx)

    state
    |> expect("compose/1 returns single system message", fn ->
      match?([%{role: :system, content: c}] when is_binary(c), PromptComposer.compose(ctx))
    end)
    |> expect("prompt embeds situation description", fn ->
      String.contains?(prompt, Situation.description(:inactive_students))
    end)
    |> expect("prompt embeds tone directive (encouraging)", fn ->
      String.contains?(prompt, "encouraging, supportive tone")
    end)
    |> expect("prompt instructs JSON output", fn ->
      String.contains?(prompt, "JSON object") and
        String.contains?(prompt, ~s("subject")) and
        String.contains?(prompt, ~s("body"))
    end)
    |> expect("prompt lists supported placeholders", fn ->
      Enum.all?(
        ["{first_name}", "{student_name}", "{instructor_name}", "{course_name}"],
        &String.contains?(prompt, &1)
      )
    end)
    |> expect("prompt includes course title and scope label", fn ->
      String.contains?(prompt, "Photosynthesis 101") and
        String.contains?(prompt, "Unit 2")
    end)
  end

  ## 4. DB rows

  defp test_db_rows(state) do
    state
    |> expect(":instructor_email is in FeatureConfig.features/0", fn ->
      :instructor_email in FeatureConfig.features()
    end)
    |> expect(~s|ServiceConfig "instructor-email-default" exists|, fn ->
      sc = Oli.Repo.get_by(ServiceConfig, name: "instructor-email-default")

      if is_nil(sc) do
        {:error,
         "ServiceConfig 'instructor-email-default' not found in DB. Did you run `mix ecto.reset` (or seeds)?"}
      else
        :ok
      end
    end)
    |> expect("FeatureConfig row for :instructor_email exists with section_id=nil", fn ->
      rows =
        Oli.Repo.all(
          from f in FeatureConfig, where: f.feature == :instructor_email and is_nil(f.section_id)
        )

      case rows do
        [_one] -> :ok
        [] -> {:error, "no FeatureConfig row found for :instructor_email"}
        many -> {:error, "expected 1 row, found #{length(many)}"}
      end
    end)
    |> expect("load_for(nil, :instructor_email) returns the seeded ServiceConfig", fn ->
      sc = FeatureConfig.load_for(nil, :instructor_email)

      if sc.name == "instructor-email-default" do
        :ok
      else
        {:error, "expected 'instructor-email-default', got #{inspect(sc.name)}"}
      end
    end)
    |> expect("load_for(non-nil section, :instructor_email) falls back to global default", fn ->
      sc = FeatureConfig.load_for(99_999, :instructor_email)

      if sc.name == "instructor-email-default" do
        :ok
      else
        {:error, "expected fallback to global, got #{inspect(sc.name)}"}
      end
    end)
  end

  ## 5. AIDraftFacade — mocked AI

  defp test_facade_mocked(state) do
    {:ok, ctx} = sample_context()

    fake_ok = fn _, _, _ ->
      payload =
        Jason.encode!(%{
          "subject" => "Checking in — Test",
          "body" => "Hi {student_name},\n\nNoticing you haven't logged in this week..."
        })

      {:ok, %{content: payload, metadata: %{model: "fake", tokens: 7}}}
    end

    state
    |> expect("generate/2 returns {:ok, draft} with subject/body/metadata", fn ->
      case AIDraftFacade.generate(ctx, execution_fun: fake_ok) do
        {:ok, %{subject_template: s, body_template: b, metadata: m}}
        when is_binary(s) and is_binary(b) and is_map(m) ->
          :ok

        other ->
          {:error, "unexpected: #{inspect(other)}"}
      end
    end)
    |> expect(":timeout from execution maps to {:error, :timeout}", fn ->
      AIDraftFacade.generate(ctx, execution_fun: fn _, _, _ -> {:error, :timeout} end) ==
        {:error, :timeout}
    end)
    |> expect(":recv_timeout maps to {:error, :timeout}", fn ->
      AIDraftFacade.generate(ctx, execution_fun: fn _, _, _ -> {:error, :recv_timeout} end) ==
        {:error, :timeout}
    end)
    |> expect("arbitrary provider error maps to {:error, :provider_error}", fn ->
      AIDraftFacade.generate(ctx, execution_fun: fn _, _, _ -> {:error, :rate_limited} end) ==
        {:error, :provider_error}
    end)
    |> expect("invalid JSON content maps to {:error, :parse_failure}", fn ->
      AIDraftFacade.generate(ctx,
        execution_fun: fn _, _, _ -> {:ok, %{content: "not json", metadata: %{}}} end
      ) == {:error, :parse_failure}
    end)
    |> expect("missing 'body' key maps to {:error, :parse_failure}", fn ->
      AIDraftFacade.generate(ctx,
        execution_fun: fn _, _, _ ->
          {:ok, %{content: ~s({"subject": "x"}), metadata: %{}}}
        end
      ) == {:error, :parse_failure}
    end)
    |> expect("non-binary content maps to {:error, :parse_failure}", fn ->
      AIDraftFacade.generate(ctx,
        execution_fun: fn _, _, _ -> {:ok, %{content: nil, metadata: %{}}} end
      ) == {:error, :parse_failure}
    end)
  end

  ## 6. Telemetry events

  defp test_telemetry(state) do
    {:ok, ctx} = sample_context()
    handler_id = "phase1_check_#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      [
        [:oli, :instructor_dashboard, :email, :draft, :generated],
        [:oli, :instructor_dashboard, :email, :draft, :failed]
      ],
      fn event, measurements, metadata, _ ->
        send(test_pid, {:tel, event, measurements, metadata})
      end,
      nil
    )

    state =
      expect(state, "emits :generated event on success", fn ->
        AIDraftFacade.generate(ctx,
          execution_fun: fn _, _, _ ->
            {:ok,
             %{
               content: Jason.encode!(%{"subject" => "S", "body" => "B"}),
               metadata: %{}
             }}
          end
        )

        receive do
          {:tel, [_, _, _, _, :generated], %{duration_ms: d}, %{feature: :instructor_email}}
          when is_integer(d) ->
            :ok
        after
          200 -> {:error, "did not receive :generated event within 200ms"}
        end
      end)

    state =
      expect(state, "emits :failed event with reason on parse error", fn ->
        AIDraftFacade.generate(ctx,
          execution_fun: fn _, _, _ -> {:ok, %{content: "garbage", metadata: %{}}} end
        )

        receive do
          {:tel, [_, _, _, _, :failed], _, %{reason: :parse_failure}} -> :ok
        after
          200 -> {:error, "did not receive :failed/:parse_failure event"}
        end
      end)

    :telemetry.detach(handler_id)
    state
  end

  ## 7. (Optional) Real AI

  defp maybe_real_ai(state) do
    case System.get_env("EMAIL_PHASE1_REAL_AI") do
      "1" -> section(state, "7. Real AI call (live)", &test_real_ai/1)
      _ -> skip_real_ai(state)
    end
  end

  defp skip_real_ai(state) do
    IO.puts("\n#{@bold}#{@yellow}━━ 7. Real AI call (skipped)#{@reset}")
    IO.puts("    Set EMAIL_PHASE1_REAL_AI=1 to enable. Requires OPENAI_API_KEY or ANTHROPIC_API_KEY.")
    state
  end

  defp test_real_ai(state) do
    {:ok, ctx} = sample_context()

    case AIDraftFacade.generate(ctx) do
      {:ok, draft} ->
        IO.puts("\n  #{@bold}Subject:#{@reset} #{draft.subject_template}")
        IO.puts("  #{@bold}Body:#{@reset}")
        IO.puts(indent(draft.body_template, "    "))
        IO.puts("  #{@bold}Metadata:#{@reset} #{inspect(draft.metadata)}")

        state
        |> pass("real provider returned :ok")
        |> expect("subject is non-empty", fn -> draft.subject_template != "" end)
        |> expect("body is non-empty", fn -> draft.body_template != "" end)

      {:error, reason} ->
        fail(state, "real provider returned {:error, #{inspect(reason)}}",
          "check API keys + provider availability")
    end
  end

  defp sample_context do
    ContextBuilder.build(%{
      section_id: 1,
      course_title: "Intro to Gardening",
      scope_label: "Module 3",
      situation_key: :struggling_students,
      recipients: [
        %{
          student_id: 1,
          email: "alex@example.com",
          given_name: "Alex",
          family_name: "Kim"
        }
      ]
    })
  end

  defp indent(text, prefix) do
    text |> String.split("\n") |> Enum.map(&(prefix <> &1)) |> Enum.join("\n")
  end

  defp summary(state) do
    total = state.passed + state.failed

    IO.puts("\n#{@bold}══════════════════════════════════════#{@reset}")

    color = if state.failed == 0, do: @green, else: @red
    IO.puts("#{color}#{@bold}Result: #{state.passed}/#{total} passed#{@reset}")

    if state.failed > 0 do
      IO.puts("\n#{@red}Failures:#{@reset}")

      state.failures
      |> Enum.reverse()
      |> Enum.with_index(1)
      |> Enum.each(fn {{msg, detail}, i} ->
        IO.puts("  #{i}. #{msg}\n     #{detail}")
      end)

      System.halt(1)
    end
  end
end

EmailPhase1Check.run()
