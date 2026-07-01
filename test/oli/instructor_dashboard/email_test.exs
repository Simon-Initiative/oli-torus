defmodule Oli.InstructorDashboard.EmailTest do
  use Oli.DataCase, async: false
  use Oban.Testing, repo: Oli.Repo

  alias Oli.InstructorDashboard.Email
  alias Oli.InstructorDashboard.Email.{EmailContext, SendWorker}

  @validation_blocked [:oli, :instructor_dashboard, :email, :send, :validation_blocked]

  defp recipient(overrides \\ %{}) do
    Map.merge(
      %{
        student_id: 101,
        email: "alex@example.edu",
        given_name: "Alex",
        family_name: "Kim"
      },
      overrides
    )
  end

  defp context(recipients, overrides \\ %{}) do
    base = %EmailContext{
      section_id: 42,
      course_title: "Calculus 101",
      instructor_name: "Dr. Sage",
      instructor_email: "sage@example.edu",
      scope_label: "Module 3",
      situation_key: :struggling_students,
      recipients: recipients,
      tone: :neutral,
      recipient_count: length(recipients)
    }

    Map.merge(base, overrides)
  end

  defp body_slate(text) do
    [%{"type" => "p", "children" => [%{"text" => text}]}]
  end

  defp valid_draft do
    %{
      subject: "Update on {course_name}",
      body_slate: body_slate("Hi {first_name}, your progress in {course_name} needs attention.")
    }
  end

  defp attach_handler(events) do
    handler_id = "email-test-#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  describe "validate/2" do
    test "returns :ok for a valid draft + context" do
      assert :ok = Email.validate(valid_draft(), context([recipient()]))
    end

    test "returns error reasons when tokens are unresolvable" do
      ctx = context([recipient(%{given_name: nil})])

      assert {:error, errors} = Email.validate(valid_draft(), ctx)

      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, "{first_name}", _} -> true
               _ -> false
             end)
    end

    test "returns error for unsupported AI-typo tokens" do
      draft = %{valid_draft() | subject: "Hi {firstName}"}

      assert {:error, errors} = Email.validate(draft, context([recipient()]))
      assert {:unsupported_placeholder, "{firstName}"} in errors
    end
  end

  describe "send_emails/2 — happy path" do
    test "enqueues one SendWorker job per recipient" do
      recipients = [
        recipient(),
        recipient(%{student_id: 202, email: "bo@example.edu", given_name: "Bo"})
      ]

      ctx = context(recipients)

      assert {:ok, %{enqueued: 2, draft_id: draft_id}} =
               Email.send_emails(valid_draft(), ctx)

      assert is_binary(draft_id)
      assert_enqueued(worker: SendWorker, args: %{"user_id" => 101})
      assert_enqueued(worker: SendWorker, args: %{"user_id" => 202})
    end

    test "each enqueued job carries draft_id, section_id, situation_key" do
      ctx = context([recipient()])

      {:ok, %{draft_id: draft_id}} = Email.send_emails(valid_draft(), ctx)

      assert_enqueued(
        worker: SendWorker,
        args: %{
          "draft_id" => draft_id,
          "section_id" => 42,
          "situation_key" => "struggling_students",
          "user_id" => 101
        }
      )
    end

    test "rendered email contains substituted subject + body" do
      ctx = context([recipient()])

      {:ok, _} = Email.send_emails(valid_draft(), ctx)

      [job] = all_enqueued(worker: SendWorker)
      email_args = job.args["email"]

      assert email_args["subject"] == "Update on Calculus 101"
      assert email_args["html_body"] =~ "Hi Alex, your progress in Calculus 101 needs attention."
      assert email_args["text_body"] =~ "Hi Alex"
    end

    test "from address is the system base address; reply_to is the instructor" do
      ctx = context([recipient()])

      {:ok, _} = Email.send_emails(valid_draft(), ctx)

      [job] = all_enqueued(worker: SendWorker)
      email_args = job.args["email"]

      expected_from_name = Application.get_env(:oli, :email_from_name)
      expected_from_email = Application.get_env(:oli, :email_from_address)

      assert email_args["from"] == %{"name" => expected_from_name, "email" => expected_from_email}
      assert %{"name" => "Dr. Sage", "email" => "sage@example.edu"} = email_args["reply_to"]
    end

    test "omits reply_to when instructor_email is nil" do
      ctx = context([recipient()], %{instructor_email: nil})

      {:ok, _} = Email.send_emails(valid_draft(), ctx)

      [job] = all_enqueued(worker: SendWorker)
      assert job.args["email"]["reply_to"] == nil
    end
  end

  describe "send_emails/2 — validation failure" do
    test "returns {:error, reasons} and does NOT enqueue any jobs" do
      ctx = context([recipient(%{given_name: nil})])

      assert {:error, [_ | _] = errors} = Email.send_emails(valid_draft(), ctx)

      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, "{first_name}", _} -> true
               _ -> false
             end)

      refute_enqueued(worker: SendWorker)
    end

    test "emits :validation_blocked telemetry with the reasons" do
      attach_handler([@validation_blocked])

      ctx = context([recipient(%{given_name: nil})])

      assert {:error, _} = Email.send_emails(valid_draft(), ctx)

      assert_received {:telemetry_event, @validation_blocked, _, metadata}
      assert metadata.section_id == 42
      assert metadata.situation_key == :struggling_students
      assert is_list(metadata.reasons)
    end

    test "telemetry reasons strip PII (recipient emails replaced with count)" do
      attach_handler([@validation_blocked])

      ctx =
        context([
          recipient(%{given_name: nil, email: "alex@example.edu"}),
          recipient(%{student_id: 202, given_name: nil, email: "bo@example.edu"})
        ])

      {:error, errors} = Email.send_emails(valid_draft(), ctx)

      # Caller-facing error tuple STILL carries raw emails for UI display.
      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, _, ["alex@example.edu", "bo@example.edu"]} -> true
               _ -> false
             end)

      assert_received {:telemetry_event, @validation_blocked, _, metadata}

      # Telemetry payload must NOT contain any raw email string.
      reasons_inspected = inspect(metadata.reasons)
      refute reasons_inspected =~ "alex@example.edu"
      refute reasons_inspected =~ "bo@example.edu"

      # Telemetry reasons carry counts instead.
      assert Enum.any?(metadata.reasons, fn
               {:unresolvable_placeholder, _, count} -> count == 2
               _ -> false
             end)
    end
  end

  describe "bulk enqueue scales to large cohorts" do
    test "enqueues one job per recipient for a 60-recipient send" do
      recipients =
        for i <- 1..60 do
          recipient(%{student_id: i, email: "user#{i}@example.edu"})
        end

      ctx = context(recipients)

      assert {:ok, %{enqueued: 60}} = Email.send_emails(valid_draft(), ctx)

      assert length(all_enqueued(worker: SendWorker)) == 60
    end
  end

  describe "unique constraint via Oban [draft_id, user_id]" do
    test "second insert with same draft_id + user_id is a no-op (dedup)" do
      ctx = context([recipient()])

      assert {:ok, %{enqueued: 1}} = Email.send_emails(valid_draft(), ctx)
      assert [%{args: %{"user_id" => 101}}] = all_enqueued(worker: SendWorker)

      # Hand-craft a second insert with the SAME draft_id + user_id but a different
      # underlying email. Oban's `unique` constraint should reject it.
      [job1] = all_enqueued(worker: SendWorker)
      duplicate_args = Map.put(job1.args, "section_id", 9999)

      {:ok, result} = duplicate_args |> SendWorker.new() |> Oban.insert()
      # `Oban.insert/1` returns the existing conflicting job (not a fresh one)
      assert result.conflict?
    end
  end

  describe "brace-escape regression (§2.2.d)" do
    # Guards Option B (post-render string replace): if the HTML writer ever
    # starts escaping `{` / `}`, the post-render substitution flow would
    # silently break — recipients would see raw `&#123;first_name&#125;`.
    test "Oli.Rendering.Content.Html.escape_xml!/1 preserves curly braces" do
      assert Oli.Rendering.Content.Html.escape_xml!("{first_name}") == "{first_name}"
      assert Oli.Rendering.Content.Html.escape_xml!("Hi {first_name}!") == "Hi {first_name}!"
    end
  end

  describe "Premailex wrap requirement" do
    test "Premailex.to_text returns \"\" for an unwrapped HTML fragment" do
      assert Premailex.to_text("<p>Hi {first_name}</p>") == ""
    end

    test "Premailex.to_text yields text with tokens intact when wrapped in <html><body>" do
      wrapped = "<html><body><p>Hi {first_name}</p></body></html>"
      text = Premailex.to_text(wrapped)
      assert String.contains?(text, "{first_name}")
    end
  end

  describe "internal /course/link rendering threads section_slug" do
    test "rewrites /course/link/:slug to a section-scoped lesson URL" do
      body = [
        %{
          "type" => "p",
          "children" => [
            %{
              "type" => "a",
              "href" => "/course/link/welcome-page",
              "children" => [%{"text" => "Start here"}]
            }
          ]
        }
      ]

      ctx = context([recipient()], %{section_slug: "math-101"})

      {:ok, _} = Email.send_emails(%{subject: "Welcome", body_slate: body}, ctx)

      [job] = all_enqueued(worker: SendWorker)
      html = job.args["email"]["html_body"]

      assert html =~ "/sections/math-101/lesson/welcome-page"
    end
  end

  describe "render pipeline silences point-marker warnings" do
    import ExUnit.CaptureLog

    test "render with is_annotation_level: false does not log 'missing id' warning" do
      slate = [%{"type" => "p", "children" => [%{"text" => "Hi {first_name}"}]}]

      log =
        capture_log(fn ->
          Email.send_emails(
            %{subject: "S", body_slate: slate},
            context([recipient()])
          )
        end)

      refute log =~ "Content element missing id"
    end
  end

  describe "validator covers empty-string given_name (canonical seam)" do
    test "ContextBuilder accepts given_name=\"\" and Validator catches it as unresolvable" do
      {:ok, ctx} =
        Oli.InstructorDashboard.Email.ContextBuilder.build(%{
          section_id: 42,
          course_title: "Calculus 101",
          instructor_name: "Dr. Sage",
          scope_label: "Module 3",
          situation_key: :struggling_students,
          recipients: [
            %{
              student_id: 101,
              email: "alex@example.edu",
              given_name: "",
              family_name: "Kim"
            }
          ]
        })

      assert {:error, errors} = Email.validate(valid_draft(), ctx)

      assert Enum.any?(errors, fn
               {:unresolvable_placeholder, "{first_name}", ["alex@example.edu"]} -> true
               _ -> false
             end)
    end
  end
end
