defmodule Oli.InstructorDashboard.DataSnapshot.DatasetRegistry do
  @moduledoc """
  Stable dataset registry mapping export profiles to projection requirements
  and serializer adapters.
  """

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.MapRows

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
      spec(:summary, "summary.csv", [:summary], []),
      spec(:progress, "progress.csv", [:progress], []),
      spec(:student_support, "student_support.csv", [:student_support], []),
      spec(:challenging_objectives, "challenging_objectives.csv", [:challenging_objectives], []),
      spec(:assessments, "assessments.csv", [:assessments], [])
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
        :allow_partial_with_manifest
      )
    ]
  end

  defp spec(dataset_id, filename, required_projections, optional_projections, failure_policy \\ :fail_closed) do
    %{
      dataset_id: dataset_id,
      filename: filename,
      required_projections: required_projections,
      optional_projections: optional_projections,
      serializer_module: MapRows,
      failure_policy: failure_policy
    }
  end
end
