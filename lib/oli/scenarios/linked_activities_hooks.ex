defmodule Oli.Scenarios.LinkedActivitiesHooks do
  @moduledoc """
  Assertions for the real linked-activities scenario workflow.

  The scenario DSL has no domain assertion for instructor linked activities, so this hook
  delegates directly to the production resolver after authoring, publishing, delivery, and
  learner attempt directives have completed.
  """

  import ExUnit.Assertions
  import Ecto.Query, only: [from: 2]

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.LinkedActivities
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.Summaries
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
    assert shared.attempts == 4
    assert shared.percent_correct == 75.0

    no_attempt = Enum.find(parent_rows, &(&1.resource_id == activity_ids["no_attempt"]))
    assert no_attempt.attempts == 0
    assert no_attempt.percent_correct == 0.0

    assert Enum.all?(lesson_activity_refs(section.id), &(&1 == [])),
           "scenario pages unexpectedly carry activity_refs; this assertion no longer isolates the observed path"

    shared_pages = Enum.map(shared.page_contexts, & &1.page_resource_id) |> Enum.sort()

    assert length(shared_pages) == 2,
           "expected the shared activity to resolve both pages it was answered on, got #{inspect(shared_pages)}"

    assert shared.canonical_page_context.page_resource_id in shared_pages

    assert Enum.count(
             Enum.find(parent_rows, &(&1.resource_id == activity_ids["parent_only"])).page_contexts
           ) == 1

    assert no_attempt.page_contexts == []
    assert no_attempt.canonical_page_context == nil

    assert_shared_summary_spans_both_pages(section, shared)

    state
  end

  # The row totals every page the activity appears on, so the expanded pane must describe the same
  # population: one correct answer on one page, one incorrect on the other.
  defp assert_shared_summary_spans_both_pages(section, shared) do
    summary =
      Summaries.across_pages(
        section,
        shared,
        Map.new(Oli.Activities.list_activity_registrations(), &{&1.id, &1}),
        Sections.enrolled_students(section.slug, [:context_learner])
      )

    assert summary, "no summary was produced for the shared activity"

    assert summary.total_attempts_count == shared.attempts,
           "pane counted #{summary.total_attempts_count} attempts while the row counted #{shared.attempts}"

    assert_in_delta summary.all_attempt_pct * 100,
                    shared.percent_correct,
                    0.05,
                    "pane reported #{summary.all_attempt_pct * 100}% while the row reported #{shared.percent_correct}%"

    # Four attempts from three students: one learner answered on both pages. A pin that used the
    # attempt count here would pass while conflating the two measures.
    assert summary.students_with_attempts_count == 3,
           "pane saw #{summary.students_with_attempts_count} student(s); the pages together have 3"

    assert_choice_counts_combine_across_pages(summary)
  end

  # Learners chose the same answer on different pages. Staging resolves a choice by first match, so
  # unmerged rows would report one page and lose the other. These counts are responses, not students:
  # one learner answered on both pages, which is why A exceeds the learners who chose it.
  defp assert_choice_counts_combine_across_pages(summary) do
    counts =
      summary.student_responses
      |> Map.values()
      |> List.flatten()
      |> Map.new(fn choice -> {choice["label"], choice["count"]} end)

    assert counts["A."] == 3,
           "the correct answer was chosen three times across both pages; the pane shows #{inspect(counts)}"

    assert counts["B."] == 1,
           "the incorrect answer was chosen once; the pane shows #{inspect(counts)}"

    assert Enum.sum(Map.values(counts)) > summary.students_with_attempts_count,
           "this fixture must keep responses and students apart, or a pin that conflates them passes"
  end

  defp lesson_activity_refs(section_id) do
    revision_ids =
      SectionResourceDepot.get_lessons(section_id)
      |> Enum.map(& &1.revision_id)
      |> Enum.reject(&is_nil/1)

    Oli.Repo.all(
      from(revision in Oli.Resources.Revision,
        where: revision.id in ^revision_ids,
        select: revision.activity_refs
      )
    )
  end

  defp objective_id(objectives, title) do
    case Enum.find(objectives, &(&1.title == title)) do
      nil -> raise "Objective #{title} was not found in the published section"
      objective -> objective.resource_id
    end
  end

  defp row_ids(rows), do: Enum.map(rows, & &1.resource_id) |> Enum.sort()
end
