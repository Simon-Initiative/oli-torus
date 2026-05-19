defmodule Oli.InstructorDashboard.Oracles.ObjectivesProficiency do
  @moduledoc """
  Returns objective proficiency distributions for objectives contained within scope.
  """

  use Oli.Dashboard.Oracle

  require Logger

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Oracles.Helpers

  @impl true
  def key, do: :oracle_instructor_objectives_proficiency

  @impl true
  def version, do: 2

  @impl true
  def load(%OracleContext{} = context, _opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context) do
      objective_ids = Sections.get_section_contained_objectives(section_id, scope.container_id)

      all_objective_resources =
        SectionResourceDepot.objectives_with_effective_children(section_id)

      objective_id_set = MapSet.new(objective_ids)

      objective_section_resources =
        Enum.filter(all_objective_resources, &MapSet.member?(objective_id_set, &1.resource_id))

      case objective_ids -- Enum.map(objective_section_resources, & &1.resource_id) do
        [] ->
          :ok

        missing_objective_ids ->
          Logger.warning(
            "objectives_proficiency_oracle.missing_section_resources section_id=#{section_id} missing_objective_ids=#{inspect(missing_objective_ids)}"
          )
      end

      section = Helpers.section(section_id)

      objective_rows =
        Metrics.objectives_proficiency(section_id, section.slug, objective_section_resources)

      objective_rows =
        objective_rows
        |> Enum.map(fn objective ->
          %{
            objective_id: Map.get(objective, :sub_objective_id),
            title: Map.get(objective, :title),
            proficiency_distribution: Map.get(objective, :proficiency_distribution, %{})
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
