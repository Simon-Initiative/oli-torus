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
  def version, do: 1

  @impl true
  def load(%OracleContext{} = context, _opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context) do
      objective_ids = Sections.get_section_contained_objectives(section_id, scope.container_id)

      objective_section_resources =
        SectionResourceDepot.get_resources_by_ids(section_id, objective_ids)

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

      objective_rows
      |> Enum.map(fn objective ->
        %{
          objective_id: Map.get(objective, :sub_objective_id),
          title: Map.get(objective, :title),
          proficiency_distribution: Map.get(objective, :proficiency_distribution, %{})
        }
      end)
      |> Enum.sort_by(& &1.objective_id)
      |> then(&{:ok, &1})
    end
  end
end
