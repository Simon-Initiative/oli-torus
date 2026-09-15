defmodule Oli.Scenarios.LinkedActivitiesHooks do
  @moduledoc """
  Assertions for the real linked-activities scenario workflow.

  The scenario DSL has no domain assertion for instructor linked activities, so this hook
  delegates directly to the production resolver after authoring, publishing, delivery, and
  learner attempt directives have completed.
  """

  import ExUnit.Assertions

  alias Oli.Delivery.Sections.LinkedActivities
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Scenarios.DirectiveTypes.ExecutionState

  @project_name "linked_activities_project"
  @section_name "linked_activities_section"

  def assert_linked_activity_rows(%ExecutionState{} = state) do
    section = Map.fetch!(state.sections, @section_name)

    PostProcessing.apply(section, :related_activities)
    Oli.Delivery.DepotCoordinator.clear(SectionResourceDepot.depot_desc(), section.id)

    objective_resources = SectionResourceDepot.objectives_with_effective_children(section.id)

    parent_id = objective_id(objective_resources, "Linked Parent")
    child_one_id = objective_id(objective_resources, "Linked Child One")
    child_two_id = objective_id(objective_resources, "Linked Child Two")

    activity_ids =
      ["parent_only", "child_one_only", "shared", "child_two_only", "no_attempt", "unrelated"]
      |> Map.new(fn virtual_id ->
        {virtual_id,
         Map.fetch!(state.activity_virtual_ids, {@project_name, virtual_id}).resource_id}
      end)

    parent_rows = LinkedActivities.get_activities_for_objective(section, parent_id)
    child_one_rows = LinkedActivities.get_activities_for_objective(section, child_one_id)
    child_two_rows = LinkedActivities.get_activities_for_objective(section, child_two_id)

    assert row_ids(parent_rows) ==
             Enum.sort([
               activity_ids["parent_only"],
               activity_ids["child_one_only"],
               activity_ids["shared"],
               activity_ids["child_two_only"],
               activity_ids["no_attempt"]
             ]),
           "parent rows=#{inspect(parent_rows)} objectives=#{inspect(objective_resources)}"

    assert row_ids(child_one_rows) ==
             Enum.sort([activity_ids["child_one_only"], activity_ids["shared"]])

    assert row_ids(child_two_rows) == [activity_ids["child_two_only"]]
    refute activity_ids["unrelated"] in row_ids(parent_rows)
    assert Enum.count(parent_rows, &(&1.resource_id == activity_ids["shared"])) == 1

    shared = Enum.find(parent_rows, &(&1.resource_id == activity_ids["shared"]))
    assert shared.attempts == 2
    assert shared.percent_correct == 50.0

    no_attempt = Enum.find(parent_rows, &(&1.resource_id == activity_ids["no_attempt"]))
    assert no_attempt.attempts == 0
    assert no_attempt.percent_correct == 0.0

    state
  end

  defp objective_id(objectives, title) do
    case Enum.find(objectives, &(&1.title == title)) do
      nil -> raise "Objective #{title} was not found in the published section"
      objective -> objective.resource_id
    end
  end

  defp row_ids(rows), do: Enum.map(rows, & &1.resource_id) |> Enum.sort()
end
