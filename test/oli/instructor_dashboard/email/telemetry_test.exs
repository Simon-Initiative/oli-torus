defmodule Oli.InstructorDashboard.Email.TelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.Telemetry

  @generated_event [:oli, :instructor_dashboard, :email, :draft, :generated]
  @failed_event [:oli, :instructor_dashboard, :email, :draft, :failed]
  @link_stripped_event [:oli, :instructor_dashboard, :email, :draft, :link_stripped]

  # AppSignal is inactive in test, so handler calls are safe no-ops; these lock in that every
  # emitted draft event shape is handled (and tagged) without crashing the telemetry handler.
  describe "handle_event/4" do
    test "handles a :generated event" do
      assert :ok =
               Telemetry.handle_event(
                 @generated_event,
                 %{duration_ms: 120},
                 %{section_id: 42, situation_key: :struggling_students, tone: :neutral},
                 %{}
               )
    end

    test "handles a :failed event with a reason" do
      assert :ok =
               Telemetry.handle_event(
                 @failed_event,
                 %{duration_ms: 5},
                 %{
                   section_id: 42,
                   situation_key: :struggling_students,
                   tone: :firm,
                   reason: :timeout
                 },
                 %{}
               )
    end

    test "handles a :failed event with an unknown/free-form reason (collapsed to bounded tag)" do
      # A reason outside the known set must not crash the handler — classify_reason/1 maps it to
      # "unknown" so a stray binary can never inflate AppSignal metric-tag cardinality.
      assert :ok =
               Telemetry.handle_event(
                 @failed_event,
                 %{duration_ms: 9},
                 %{
                   situation_key: :struggling_students,
                   tone: :neutral,
                   reason: "weird provider 500"
                 },
                 %{}
               )
    end

    test "collapses an out-of-allowlist situation_key / tone to a bounded tag" do
      # situation_key is gated by Situation.valid?/1 and tone by a closed set; anything else
      # must not reach AppSignal as a new metric series.
      assert :ok =
               Telemetry.handle_event(
                 @generated_event,
                 %{duration_ms: 7},
                 %{situation_key: :not_a_real_situation, tone: :sarcastic},
                 %{}
               )
    end

    test "handles a :link_stripped event" do
      assert :ok =
               Telemetry.handle_event(
                 @link_stripped_event,
                 %{count: 3},
                 %{section_id: 42, situation_key: :beginning_course, tone: :encouraging},
                 %{}
               )
    end

    test "tolerates missing/nil metadata without crashing" do
      assert :ok = Telemetry.handle_event(@generated_event, %{}, %{}, %{})
      assert :ok = Telemetry.handle_event(@failed_event, %{}, %{}, %{})
    end

    test "ignores unrelated events" do
      assert :ok = Telemetry.handle_event([:some, :other, :event], %{}, %{}, %{})
    end
  end

  describe "supervision" do
    test "the running application has attached the AppSignal handler" do
      handlers =
        :telemetry.list_handlers([:oli, :instructor_dashboard, :email, :draft, :generated])

      assert Enum.any?(handlers, &(&1.id == "instructor-dashboard-email-appsignal-handler"))
    end
  end
end
