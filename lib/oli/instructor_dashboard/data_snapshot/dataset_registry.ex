defmodule Oli.InstructorDashboard.DataSnapshot.DatasetRegistry do
  @moduledoc """
  Stable dataset registry mapping export profiles to projection requirements
  and serializer adapters.
  """

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.AssessmentScoresDistribution
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.AssessmentSummary
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.ChallengingLearningObjectives
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.CourseSummaryMetrics
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.DashboardMetadata
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.MapRows
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.StudentProgressByUnit
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.StudentSupportList
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.StudentSupportSummary

  @type failure_policy :: :fail_closed | :allow_partial_with_manifest

  @type dataset_spec :: %{
          required(:dataset_id) => atom(),
          required(:filename) => String.t(),
          required(:required_projections) => [atom()],
          required(:optional_projections) => [atom()],
          required(:serializer_module) => module(),
          required(:failure_policy) => failure_policy()
        }

  @type export_profile :: :default | :instructor_dashboard | :with_optional_ai
  @type error :: {:unknown_export_profile, term()}

  @spec datasets_for(export_profile()) :: {:ok, [dataset_spec()]} | {:error, error()}
  def datasets_for(:default), do: {:ok, default_specs()}
  def datasets_for(:instructor_dashboard), do: {:ok, default_specs()}
  def datasets_for(:with_optional_ai), do: {:ok, with_optional_ai_specs()}
  def datasets_for(profile), do: {:error, {:unknown_export_profile, profile}}

  @spec dataset_spec(atom()) :: {:ok, dataset_spec()} | {:error, {:unknown_dataset, atom()}}
  def dataset_spec(dataset_id) when is_atom(dataset_id) do
    specs = default_specs() ++ with_optional_ai_only_specs()

    case Enum.find(specs, &(Map.get(&1, :dataset_id) == dataset_id)) do
      nil -> {:error, {:unknown_dataset, dataset_id}}
      spec -> {:ok, spec}
    end
  end

  defp default_specs do
    [
      spec(
        :dashboard_metadata,
        "dashboard_metadata.csv",
        [:progress, :student_support],
        [],
        DashboardMetadata
      ),
      spec(
        :course_summary_metrics,
        "course_summary_metrics.csv",
        [:progress, :student_support, :challenging_objectives, :assessments],
        [],
        CourseSummaryMetrics
      ),
      spec(
        :student_progress,
        "student_progress.csv",
        [:progress],
        [],
        StudentProgressByUnit
      ),
      spec(
        :student_support_summary,
        "student_support_summary.csv",
        [:student_support],
        [],
        StudentSupportSummary
      ),
      spec(
        :student_support_list,
        "student_support_list.csv",
        [:student_support],
        [],
        StudentSupportList
      ),
      spec(
        :challenging_learning_objectives,
        "challenging_learning_objectives.csv",
        [:challenging_objectives],
        [],
        ChallengingLearningObjectives
      ),
      spec(
        :assessment_scores_distribution,
        "assessment_scores_distribution.csv",
        [:assessments],
        [],
        AssessmentScoresDistribution
      ),
      spec(
        :assessment_summary,
        "assessment_summary.csv",
        [:assessments],
        [],
        AssessmentSummary
      )
    ]
  end

  defp with_optional_ai_specs do
    default_specs() ++ with_optional_ai_only_specs()
  end

  defp with_optional_ai_only_specs do
    [
      spec(
        :ai_context,
        "ai_context.csv",
        [:ai_context],
        [],
        MapRows,
        :allow_partial_with_manifest
      )
    ]
  end

  defp spec(
         dataset_id,
         filename,
         required_projections,
         optional_projections,
         serializer_module
       ) do
    spec(
      dataset_id,
      filename,
      required_projections,
      optional_projections,
      serializer_module,
      :fail_closed
    )
  end

  defp spec(
         dataset_id,
         filename,
         required_projections,
         optional_projections,
         serializer_module,
         failure_policy
       ) do
    %{
      dataset_id: dataset_id,
      filename: filename,
      required_projections: required_projections,
      optional_projections: optional_projections,
      serializer_module: serializer_module,
      failure_policy: failure_policy
    }
  end
end
