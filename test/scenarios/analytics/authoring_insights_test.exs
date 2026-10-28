defmodule Oli.Scenarios.Analytics.AuthoringInsightsTest do
  use Oli.DataCase

  import Ecto.Query

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts
  alias Oli.Analytics.Summary.{BrowseInsights, BrowseInsightsOptions, ResourceSummary}
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Resources.ResourceType

  @scenario_path Path.join(__DIR__, "authoring_insights.scenario.yaml")

  test "aggregates authoring insights across sections and learner outcome patterns" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == []

    failed_verifications = Enum.reject(result.verifications, & &1.passed)

    assert failed_verifications == [],
           Enum.map_join(failed_verifications, "\n", & &1.message)

    assert length(result.verifications) == 12
  end

  test "missing learner summaries make activity and parent rollups unavailable" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())
    assert result.errors == []
    state = result.state
    project = state.projects["authoring_insights_course"]
    section = state.sections["analytics_section_one"]

    question_id =
      state.activity_virtual_ids[{"authoring_insights_course", "analyzed_question"}].resource_id

    activity_type = ResourceType.id_for_activity()

    # Keep submission totals and historical attempts, but remove the learner
    # summaries for one question in just one section to simulate a historical gap.
    from(s in ResourceSummary,
      where:
        s.section_id == ^section.id and s.user_id != -1 and
          s.resource_id == ^question_id and s.resource_type_id == ^activity_type
    )
    |> Repo.delete_all()

    parents =
      from(s in ResourceSummary,
        where:
          s.section_id == ^section.id and s.user_id == -1 and
            s.resource_type_id != ^activity_type,
        select: {s.resource_type_id, s.resource_id}
      )
      |> Repo.all()

    for sections <- [[], [section.id]], {type, id} <- [{activity_type, question_id} | parents] do
      [row] =
        BrowseInsights.browse_insights(
          %Paging{limit: 10, offset: 0},
          %Sorting{field: :eventually_correct, direction: :desc},
          %BrowseInsightsOptions{
            project_id: project.project.id,
            section_ids: sections,
            resource_type_id: type,
            resource_id: id
          }
        )

      assert is_nil(row.eventually_correct)
      assert row.num_attempts > 0
    end

    {_, page_id} = Enum.find(parents, fn {type, _} -> type == ResourceType.id_for_page() end)
    [page] = Oli.Publishing.DeliveryResolver.from_resource_id(section.slug, [page_id])
    students = Oli.Delivery.Sections.enrolled_students(section.slug, [:context_learner])

    [activity] =
      OliWeb.Delivery.ActivityHelpers.summarize_activity_performance(
        section,
        page,
        Map.new(Oli.Activities.list_activity_registrations(), &{&1.id, &1}),
        students,
        [question_id]
      )

    assert is_nil(activity.all_attempt_pct)
    assert activity.total_attempts_count > 0
  end
end
