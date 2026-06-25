defmodule Oli.InstructorDashboard.Email.AIDraftFacadeTest do
  use Oli.DataCase, async: false

  alias Oli.InstructorDashboard.Email.{AIDraftFacade, EmailContext}

  @generated_event [:oli, :instructor_dashboard, :email, :draft, :generated]
  @failed_event [:oli, :instructor_dashboard, :email, :draft, :failed]

  defp valid_context(overrides \\ %{}) do
    base = %EmailContext{
      section_id: 42,
      course_title: "Intro to Gardening",
      instructor_name: "Dr. Sage",
      scope_label: "Module 3",
      situation_key: :struggling_students,
      recipients: [%{student_id: 1, email: "alex@example.com"}],
      tone: :neutral,
      recipient_count: 1
    }

    Map.merge(base, overrides)
  end

  defp ok_response(subject, body, metadata \\ %{}) do
    fn _request_ctx, _messages, _service_config ->
      payload = Jason.encode!(%{"subject" => subject, "body" => body})
      {:ok, %{content: payload, metadata: metadata}}
    end
  end

  defp attach_handler(events) do
    test_pid = self()
    handler_id = "ai_draft_facade_test_#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    handler_id
  end

  describe "generate/2 — happy path (with mocked execution)" do
    test "returns parsed subject/body templates plus metadata when AI returns valid JSON" do
      execution_fun =
        ok_response(
          "Checking in — support",
          "Hi {student_name}, ...",
          %{model: "test-model", tokens: 42}
        )

      assert {:ok, result} =
               AIDraftFacade.generate(valid_context(),
                 execution_fun: execution_fun
               )

      assert result.subject_template == "Checking in — support"
      assert result.body_template == "Hi {student_name}, ..."
      assert result.metadata == %{model: "test-model", tokens: 42}
    end

    test "passes through realistic metadata shape produced by Oli.GenAI.Execution" do
      # Mirrors the metadata shape from
      # `Oli.GenAI.Execution.generation_metadata/2`: model, provider,
      # registered_model_id, service_config_id. Locks the contract callers
      # (Phase 4 LiveView) actually depend on for telemetry.
      production_metadata = %{
        model: "gpt-4-1106-preview",
        provider: :open_ai,
        registered_model_id: 7,
        service_config_id: 3
      }

      execution_fun = ok_response("S", "B", production_metadata)

      assert {:ok, result} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert result.metadata == production_metadata
    end

    test "passes response_format JSON-object provider opt to a 4-arity execution_fun" do
      test_pid = self()

      capturing_fun = fn _request_ctx, _messages, _service_config, exec_opts ->
        send(test_pid, {:captured_opts, exec_opts})
        ok_response("S", "B").(nil, nil, nil)
      end

      assert {:ok, _} = AIDraftFacade.generate(valid_context(), execution_fun: capturing_fun)

      assert_received {:captured_opts, opts}
      assert opts[:provider_opts] == [response_format: %{type: "json_object"}]
    end

    test "calls execution_fun with the composed prompt and request context" do
      capturing_fun = fn request_ctx, messages, _service_config ->
        send(self(), {:captured, request_ctx, messages})
        ok_response("S", "B").(request_ctx, messages, nil)
      end

      assert {:ok, _} =
               AIDraftFacade.generate(
                 valid_context(%{situation_key: :excelling_students, tone: :encouraging}),
                 execution_fun: capturing_fun
               )

      assert_received {:captured, request_ctx, messages}
      assert request_ctx.feature == :instructor_email
      assert request_ctx.section_id == 42
      assert request_ctx.situation_key == :excelling_students
      assert request_ctx.tone == :encouraging
      assert request_ctx.request_type == :generate
      assert request_ctx.dashboard_product == :instructor_dashboard
      assert [%{role: :system, content: content} | _] = messages
      assert is_binary(content)
      assert content =~ "JSON object"
    end

    test "emits :generated telemetry event on success" do
      attach_handler([@generated_event])

      assert {:ok, _} =
               AIDraftFacade.generate(valid_context(),
                 execution_fun: ok_response("S", "B", %{model: "x"})
               )

      assert_received {:telemetry_event, @generated_event, %{duration_ms: dur}, metadata}
      assert is_integer(dur) and dur >= 0
      assert metadata.feature == :instructor_email
      assert metadata.section_id == 42
      assert metadata.situation_key == :struggling_students
      assert metadata.tone == :neutral
      assert metadata.recipient_count == 1
    end
  end

  describe "generate/2 — error mapping" do
    test "maps :timeout from execution to :timeout for the UI" do
      attach_handler([@failed_event])

      execution_fun = fn _, _, _ -> {:error, :timeout} end

      assert {:error, :timeout} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert_received {:telemetry_event, @failed_event, _, %{reason: :timeout}}
    end

    test "maps :recv_timeout to :timeout" do
      execution_fun = fn _, _, _ -> {:error, :recv_timeout} end

      assert {:error, :timeout} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "maps :connect_timeout to :timeout" do
      execution_fun = fn _, _, _ -> {:error, :connect_timeout} end

      assert {:error, :timeout} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "maps {:timeout, ...} to :timeout" do
      execution_fun = fn _, _, _ -> {:error, {:timeout, "took too long"}} end

      assert {:error, :timeout} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "maps generic provider errors to :provider_error" do
      execution_fun = fn _, _, _ -> {:error, :rate_limited} end

      assert {:error, :provider_error} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "maps unknown error tuples to :provider_error" do
      execution_fun = fn _, _, _ -> {:error, {:unexpected, %{}}} end

      assert {:error, :provider_error} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "emits :failed telemetry event with the coarse reason when execution errors" do
      attach_handler([@failed_event])
      execution_fun = fn _, _, _ -> {:error, :rate_limited} end

      assert {:error, :provider_error} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert_received {:telemetry_event, @failed_event, _, metadata}
      assert metadata.reason == :provider_error

      # Raw provider reason must NOT leak through telemetry — could contain
      # prompt fragments, tokens, headers, or student data.
      refute Map.has_key?(metadata, :raw_reason)
      refute inspect(metadata) =~ "rate_limited"
    end
  end

  describe "generate/2 — parse failures" do
    test "returns :parse_failure when AI returns invalid JSON" do
      execution_fun = fn _, _, _ ->
        {:ok, %{content: "this is not JSON at all", metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "returns :parse_failure when JSON is valid but missing 'subject' key" do
      execution_fun = fn _, _, _ ->
        {:ok, %{content: ~s({"body": "only body"}), metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "returns :parse_failure when JSON is valid but missing 'body' key" do
      execution_fun = fn _, _, _ ->
        {:ok, %{content: ~s({"subject": "only subject"}), metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "returns :parse_failure when subject or body is empty" do
      execution_fun_empty_subject = fn _, _, _ ->
        {:ok, %{content: ~s({"subject": "", "body": "non-empty"}), metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun_empty_subject)

      execution_fun_empty_body = fn _, _, _ ->
        {:ok, %{content: ~s({"subject": "non-empty", "body": ""}), metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun_empty_body)
    end

    test "returns :parse_failure when subject is whitespace-only" do
      execution_fun = fn _, _, _ ->
        {:ok, %{content: ~s({"subject": "   \\n\\t", "body": "non-empty"}), metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "returns :parse_failure when body is whitespace-only" do
      execution_fun = fn _, _, _ ->
        {:ok, %{content: ~s({"subject": "non-empty", "body": "   \\n   "}), metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "trims leading and trailing whitespace from subject and body" do
      execution_fun = fn _, _, _ ->
        {:ok, %{content: ~s({"subject": "  S  ", "body": "\\n  B  \\n"}), metadata: %{}}}
      end

      assert {:ok, %{subject_template: "S", body_template: "B"}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "returns :parse_failure when subject or body are not strings" do
      execution_fun = fn _, _, _ ->
        {:ok, %{content: ~s({"subject": 123, "body": [1, 2]}), metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "returns :parse_failure when content is not a binary (defensive non-binary clause)" do
      execution_fun = fn _, _, _ ->
        {:ok, %{content: nil, metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "emits :failed telemetry event with reason :parse_failure" do
      attach_handler([@failed_event])

      execution_fun = fn _, _, _ ->
        {:ok, %{content: "garbage", metadata: %{}}}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert_received {:telemetry_event, @failed_event, _, %{reason: :parse_failure}}
    end

    test "returns :parse_failure when subject contains an unsupported placeholder" do
      execution_fun = fn _, _, _ ->
        {:ok,
         %{
           content: ~s({"subject": "Hi {firstName}", "body": "ok"}),
           metadata: %{}
         }}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "returns :parse_failure when body contains an unsupported placeholder" do
      execution_fun = fn _, _, _ ->
        {:ok,
         %{
           content: ~s({"subject": "ok", "body": "Hi {nickname}"}),
           metadata: %{}
         }}
      end

      assert {:error, :parse_failure} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end

    test "accepts subject + body containing only whitelisted placeholders" do
      execution_fun = fn _, _, _ ->
        {:ok,
         %{
           content: ~s({"subject": "Update on {course_name}", "body": "Hi {first_name}"}),
           metadata: %{}
         }}
      end

      assert {:ok,
              %{subject_template: "Update on {course_name}", body_template: "Hi {first_name}"}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)
    end
  end

  describe "generate/2 — AI link sanitization" do
    @link_stripped_event [:oli, :instructor_dashboard, :email, :draft, :link_stripped]

    test "keeps markdown link with a valid internal relative path" do
      # `/unauthorized` is a real route in OliWeb.Router (StaticPageController).
      body = "Hi {first_name}, please see [the page](/unauthorized) for details."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == body
    end

    test "strips markdown link with an absolute external URL, keeps label text" do
      body = "Click [here](https://imahacker.com/phish) to proceed."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "Click here to proceed."
    end

    test "strips javascript: scheme link" do
      body = "Click [run](javascript:xss) now."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "Click run now."
    end

    test "strips protocol-relative (//host) link" do
      body = "See [more](//evil.com/path)."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "See more."
    end

    test "strips link whose URL carries a query string (open-redirect guard)" do
      body = "Visit [page](/unauthorized?next=https://phishing.com) now."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "Visit page now."
    end

    test "strips path with `..` traversal segment" do
      body = "Visit [admin](/sections/foo/../../admin)."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "Visit admin."
    end

    test "strips link with a path that does not map to any router route" do
      body = "Check [details](/totally/fake/path)."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "Check details."
    end

    test "selectively strips bad links and keeps good ones in the same body" do
      body = "Mix [good](/unauthorized) and [bad](https://x.com) in one body."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "Mix [good](/unauthorized) and bad in one body."
    end

    test "leaves body unchanged when there are no markdown links" do
      body = "Plain body with {first_name} placeholder and no links."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == body
    end

    test "emits :link_stripped telemetry with the count + full base metadata" do
      attach_handler([@link_stripped_event])

      body = "Two bad links: [a](https://x.com) and [b](javascript:xss)."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, _} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert_received {:telemetry_event, @link_stripped_event, %{count: 2}, metadata}

      # Consistent with other draft events — caller can correlate by section/tone/etc.
      assert metadata.feature == :instructor_email
      assert metadata.section_id == 42
      assert metadata.situation_key == :struggling_students
      assert metadata.tone == :neutral
      assert metadata.recipient_count == 1
    end

    test "does NOT emit :link_stripped telemetry when nothing is stripped" do
      attach_handler([@link_stripped_event])

      body = "Clean body with [valid](/unauthorized) link."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, _} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      refute_received {:telemetry_event, @link_stripped_event, _, _}
    end

    test "strips bare URL in plain text" do
      body = "Visit https://evil.com today."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "Visit  today."
    end

    test "strips autolink-style bare URL" do
      body = "See <https://evil.com> for details."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "See  for details."
    end

    test "strips protocol-relative bare URL" do
      body = "Visit //evil.com/path today."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, %{body_template: body_out}} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert body_out == "Visit  today."
    end

    test "emits :link_stripped telemetry for bare URLs and autolinks" do
      attach_handler([@link_stripped_event])

      body = "Visit https://evil.com and <https://attacker.com> today."
      payload = Jason.encode!(%{"subject" => "S", "body" => body})

      execution_fun = fn _, _, _ -> {:ok, %{content: payload, metadata: %{}}} end

      assert {:ok, _} =
               AIDraftFacade.generate(valid_context(), execution_fun: execution_fun)

      assert_received {:telemetry_event, @link_stripped_event, %{count: count}, _}
      assert count >= 2
    end
  end

  describe "generate/2 — missing feature config" do
    test "returns :missing_feature_config when no FeatureConfig exists for the section's feature" do
      # Delete the seeded global row for :instructor_email so `load_for` returns
      # {:error, {:missing_feature_config, _}}, then assert the facade coerces
      # to the coarse atom and emits failure telemetry.
      Oli.Repo.delete_all(
        from(fc in Oli.GenAI.FeatureConfig, where: fc.feature == :instructor_email)
      )

      attach_handler([@failed_event])

      assert {:error, :missing_feature_config} =
               AIDraftFacade.generate(valid_context(),
                 execution_fun: fn _, _, _ ->
                   flunk("execution_fun should not be called when feature config is missing")
                 end
               )

      assert_received {:telemetry_event, @failed_event, _, %{reason: :missing_feature_config}}
    end
  end

  # ---------------------------------------------------------------------------
  # Synthetic AI fixture responses
  #
  # Generated 2026-05-08 by Claude (claude-opus-4-7) — NOT real provider
  # recordings. Each fixture mimics what a real OpenAI/Anthropic completion
  # call would return for a given situation_key/tone pairing, given the prompt
  # PromptComposer.compose/1 produces.
  #
  # Refresh from real provider output by running:
  #   EMAIL_PHASE1_REAL_AI=1 mix run scripts/dev/email_sending_phase_1_check.exs
  # then pasting the captured JSON content into the matching fixture clause.
  #
  # Edge fixtures intentionally exercise messy outputs real providers sometimes
  # produce (markdown fences, trailing prose). They document parser behavior;
  # if the facade learns to handle these, flip the matching assertions.
  # ---------------------------------------------------------------------------

  defp fixture(:struggling_students_encouraging) do
    Jason.encode!(%{
      "subject" => "Let's connect — I'm here to support you in {course_name}",
      "body" => """
      Hi {first_name},

      I wanted to reach out personally because I've noticed you've been working through {course_name}, and some of the recent material has been challenging. That's completely normal — many students hit a wall around this point, and it doesn't reflect your potential or effort.

      I'd like to help you find your footing. If you'd be open to it, please reply with a couple of times that work for a 15-minute chat this week, or stop by office hours. We can talk through whatever concept feels stuck.

      You've got this. Looking forward to hearing from you.

      Best,
      {instructor_name}
      """
    })
  end

  defp fixture(:active_students_on_track_neutral) do
    Jason.encode!(%{
      "subject" => "Quick update on your progress in {course_name}",
      "body" => """
      Hi {first_name},

      Just a quick note to let you know your progress in {course_name} is steady and on track. The work you've been doing reflects solid engagement with the material.

      Keep up the consistent effort. The next section will build on what you've already learned, so the foundation you're laying now will pay off.

      If you have any questions or want to discuss specific topics, feel free to drop by office hours.

      Best,
      {instructor_name}
      """
    })
  end

  defp fixture(:inactive_students_firm) do
    Jason.encode!(%{
      "subject" => "Following up on your engagement in {course_name}",
      "body" => """
      Hi {first_name},

      I'm reaching out because your activity in {course_name} has dropped over the past few weeks. The recent course material is foundational for what's coming next, and falling further behind will make it significantly harder to catch up.

      Please log in and complete the outstanding assignments by the end of next week. If something is going on that's preventing you from staying current, let me know — I'd rather hear it now than find out later that this could have been resolved.

      I want you to succeed in this course, but I need you to take the next step.

      Best,
      {instructor_name}
      """
    })
  end

  defp fixture(:edge_markdown_fenced) do
    """
    ```json
    {"subject": "Wrapped in code fences", "body": "Some providers (notably Claude) wrap JSON output in markdown code fences."}
    ```
    """
  end

  defp fixture(:edge_trailing_prose) do
    ~s({"subject": "Real subject", "body": "Real body"}\n\nLet me know if you'd like any adjustments to tone or length!)
  end

  defp fixture_execution_fun(name, metadata \\ %{model: "fixture", provider: :fixture}) do
    fn _ctx, _msgs, _cfg ->
      {:ok, %{content: fixture(name), metadata: metadata}}
    end
  end

  describe "generate/2 — fixture replay (synthetic AI responses)" do
    test "struggling_students + encouraging parses realistic body with placeholders" do
      context = valid_context(%{situation_key: :struggling_students, tone: :encouraging})

      assert {:ok, result} =
               AIDraftFacade.generate(context,
                 execution_fun: fixture_execution_fun(:struggling_students_encouraging)
               )

      assert is_binary(result.subject_template) and result.subject_template != ""
      assert is_binary(result.body_template) and result.body_template != ""
      assert result.body_template =~ "{first_name}"
      assert result.body_template =~ "{instructor_name}"
      assert result.metadata.provider == :fixture
    end

    test "active_students_on_track + neutral parses cleanly" do
      context = valid_context(%{situation_key: :active_students_on_track, tone: :neutral})

      assert {:ok, result} =
               AIDraftFacade.generate(context,
                 execution_fun: fixture_execution_fun(:active_students_on_track_neutral)
               )

      assert result.subject_template != ""
      assert result.body_template != ""
      assert result.body_template =~ "{course_name}"
    end

    test "inactive_students + firm parses cleanly" do
      context = valid_context(%{situation_key: :inactive_students, tone: :firm})

      assert {:ok, result} =
               AIDraftFacade.generate(context,
                 execution_fun: fixture_execution_fun(:inactive_students_firm)
               )

      assert result.subject_template != ""
      assert result.body_template != ""
    end

    test "edge: markdown-fenced JSON is extracted and parsed successfully" do
      assert {:ok, result} =
               AIDraftFacade.generate(valid_context(),
                 execution_fun: fixture_execution_fun(:edge_markdown_fenced)
               )

      assert result.subject_template == "Wrapped in code fences"
      assert result.body_template != ""
    end

    test "edge: JSON followed by trailing prose is extracted and parsed successfully" do
      assert {:ok, result} =
               AIDraftFacade.generate(valid_context(),
                 execution_fun: fixture_execution_fun(:edge_trailing_prose)
               )

      assert result.subject_template != ""
      assert result.body_template != ""
    end
  end
end
