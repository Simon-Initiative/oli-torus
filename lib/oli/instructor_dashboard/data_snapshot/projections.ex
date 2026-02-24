defmodule Oli.InstructorDashboard.DataSnapshot.Projections do
  @moduledoc """
  Capability-to-projection module registry for instructor dashboard snapshots.
  """

  alias Oli.InstructorDashboard.DataSnapshot.Projections.AiContext
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Assessments
  alias Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress
  alias Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Summary

  @type capability_key ::
          :summary
          | :progress
          | :student_support
          | :challenging_objectives
          | :assessments
          | :ai_context

  @spec modules() :: %{required(capability_key()) => module()}
  def modules do
    %{
      summary: Summary,
      progress: Progress,
      student_support: StudentSupport,
      challenging_objectives: ChallengingObjectives,
      assessments: Assessments,
      ai_context: AiContext
    }
  end
end
