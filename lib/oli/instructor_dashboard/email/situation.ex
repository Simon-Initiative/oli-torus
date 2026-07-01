defmodule Oli.InstructorDashboard.Email.Situation do
  @moduledoc """
  Enumeration of email-context situations passed from dashboard entry points
  to the AI prompt composer. Each situation key has a canonical human-readable
  description used in prompt assembly.

  Supported keys: `:struggling_students`, `:active_students_on_track`,
  `:excelling_students`, `:inactive_students`, `:incomplete_assessment`,
  `:low_proficiency_objectives`, `:beginning_course`.

  The canonical key list and descriptions are derived from existing tile
  projector taxonomies (Student Support buckets, Assessments completion
  status, Challenging Objectives proficiency tiers). See
  `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/gaps.md`
  G-J02 for the derivation.
  """

  @situations [
    :struggling_students,
    :active_students_on_track,
    :excelling_students,
    :inactive_students,
    :incomplete_assessment,
    :low_proficiency_objectives,
    :beginning_course
  ]

  @descriptions %{
    struggling_students: "Students showing progress or proficiency below 40%",
    active_students_on_track: "Students with progress ≥ 40% and proficiency ≥ 40%",
    excelling_students: "Students with both progress ≥ 80% and proficiency ≥ 80%",
    inactive_students: "Students with no recorded activity in the last 7 days",
    incomplete_assessment: "Students who have not completed an assessment",
    low_proficiency_objectives: "Students with learning objectives at ≤ 40% proficiency",
    beginning_course: "Course context with insufficient student data for specific recommendations"
  }

  @type t :: atom()

  @spec all_keys() :: [t()]
  def all_keys, do: @situations

  @spec description(t()) :: String.t()
  def description(key) when key in @situations do
    Map.fetch!(@descriptions, key)
  end

  @spec valid?(atom()) :: boolean()
  def valid?(key) when is_atom(key), do: key in @situations
  def valid?(_key), do: false
end
