defmodule Oli.InstructorDashboard.Email.SendWorkerTest do
  use ExUnit.Case, async: false

  import Swoosh.TestAssertions

  alias Oli.InstructorDashboard.Email.SendWorker
  alias Oli.Mailer.SendEmailWorker

  @attempted [:oli, :instructor_dashboard, :email, :send, :attempted]
  @succeeded [:oli, :instructor_dashboard, :email, :send, :succeeded]
  @failed [:oli, :instructor_dashboard, :email, :send, :failed]

  defp attach_handler(events) do
    handler_id = "test-handler-#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit_handler(handler_id)
  end

  defp on_exit_handler(handler_id) do
    ExUnit.Callbacks.on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp build_email(opts \\ []) do
    Swoosh.Email.new()
    |> Swoosh.Email.to(Keyword.get(opts, :to, {"Alex", "alex@example.edu"}))
    |> Swoosh.Email.from({"OLI Torus", "admin@example.edu"})
    |> Swoosh.Email.subject(Keyword.get(opts, :subject, "Test"))
    |> Swoosh.Email.html_body(Keyword.get(opts, :html_body, "<p>Hi Alex</p>"))
    |> Swoosh.Email.text_body(Keyword.get(opts, :text_body, "Hi Alex"))
  end

  defp build_job(opts \\ []) do
    email = build_email(opts)

    %Oban.Job{
      args: %{
        "email" => SendEmailWorker.serialize_email(email),
        "draft_id" => Keyword.get(opts, :draft_id, "draft-#{System.unique_integer([:positive])}"),
        "user_id" => Keyword.get(opts, :user_id, 101),
        "section_id" => Keyword.get(opts, :section_id, 42),
        "situation_key" => Keyword.get(opts, :situation_key, "struggling_students")
      },
      attempt: Keyword.get(opts, :attempt, 1)
    }
  end

  describe "perform/1" do
    test "delivers the email and returns :ok" do
      job = build_job(to: {"Bo", "bo@example.edu"}, subject: "Send test", text_body: "Body")

      assert :ok = SendWorker.perform(job)

      assert_email_sent(fn delivered ->
        delivered.to == [{"Bo", "bo@example.edu"}] and
          delivered.subject == "Send test" and
          delivered.text_body == "Body"
      end)
    end

    test "emits :attempted telemetry with full metadata before delivery" do
      attach_handler([@attempted])

      job =
        build_job(
          draft_id: "draft-abc",
          user_id: 999,
          section_id: 42,
          situation_key: "struggling_students",
          attempt: 2
        )

      assert :ok = SendWorker.perform(job)

      assert_received {:telemetry_event, @attempted, _measurements, metadata}

      assert metadata == %{
               section_id: 42,
               draft_id: "draft-abc",
               user_id: 999,
               situation_key: "struggling_students",
               attempt: 2
             }
    end

    test "emits :succeeded telemetry after successful delivery" do
      attach_handler([@succeeded])

      job = build_job(draft_id: "draft-ok", user_id: 7)

      assert :ok = SendWorker.perform(job)

      assert_received {:telemetry_event, @succeeded, _, %{draft_id: "draft-ok", user_id: 7}}
    end

    test "does NOT emit :failed when delivery succeeds" do
      attach_handler([@failed])

      job = build_job()
      assert :ok = SendWorker.perform(job)

      refute_received {:telemetry_event, @failed, _, _}
    end
  end
end
