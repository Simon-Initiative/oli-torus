defmodule Oli.InstructorDashboard.Oracles.ObjectivesProficiency do
  @moduledoc """
  Returns objective proficiency distributions for objectives contained within scope.
  """

  use Oli.Dashboard.Oracle

  require Logger

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Proficiency
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Oracles.Helpers

  @impl true
  def key, do: :oracle_instructor_objectives_proficiency

  @impl true
  def version, do: 4

  @impl true
  def load(%OracleContext{} = context, _opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context) do
      all_objective_resources =
        SectionResourceDepot.objectives_with_effective_children(section_id)

      section = Helpers.section(section_id)

      proficiency_scope =
        if is_nil(scope.container_id), do: :course, else: {:container, scope.container_id}

      with {:ok, objective_ids} <-
             Proficiency.objective_ids_for_scope(section, proficiency_scope) do
        objective_id_set = MapSet.new(objective_ids)

        objective_section_resources =
          Enum.filter(all_objective_resources, &MapSet.member?(objective_id_set, &1.resource_id))

        case objective_ids -- Enum.map(objective_section_resources, & &1.resource_id) do
          [] ->
            :ok

          missing_objective_ids ->
            Logger.warning(
              "objectives_proficiency_oracle.missing_section_resources section_id=#{section_id} missing_count=#{length(missing_objective_ids)}"
            )
        end

        learner_ids = Helpers.enrolled_learner_ids(section_id)

        with {:ok, aggregates} <-
               Proficiency.objective_aggregates(section, objective_ids, user_ids: learner_ids) do
          objective_rows =
            objective_section_resources
            |> Enum.map(fn objective ->
              aggregate = Map.fetch!(aggregates, objective.resource_id)

              %{
                objective_id: objective.resource_id,
                title: objective.title,
                proficiency_distribution:
                  Map.new(aggregate.distribution, fn {label, count} -> {label(label), count} end),
                numeric_proficiency: aggregate.numeric_score,
                # Confidence has no class aggregation policy; expose that absence instead of
                # manufacturing a value from learner confidence or categorical labels.
                confidence: nil,
                coverage: aggregate.coverage,
                contributing_count: aggregate.contributing_count,
                eligible_count: aggregate.eligible_count,
                total_count: aggregate.total_count
              }
            end)
            |> Enum.sort_by(& &1.objective_id)

          {:ok,
           %{
             objective_rows: objective_rows,
             objective_resources: all_objective_resources
           }}
        end
      end
    end
  end

  defp label(:low), do: "Low"
  defp label(:medium), do: "Medium"
  defp label(:high), do: "High"
  defp label(_label), do: "Not enough data"
end
