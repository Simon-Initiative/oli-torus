defmodule Oli.Scenarios.Analytics.AuthoringInsightsTest do
  use Oli.DataCase

  import Ecto.Query

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  alias Oli.Analytics.Summary.{
    BrowseInsights,
    BrowseInsightsOptions,
    EventualCorrectness,
    ResourceSummary
  }

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Resources.ResourceType
  alias Oli.Scenarios.DirectiveTypes.{AnswerQuestionDirective, VisitPageDirective}

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

  for missing_evidence <- [:summary, :correctness_counter] do
    @missing_evidence missing_evidence

    test "missing #{missing_evidence} makes question correctness unavailable without changing parent accuracy" do
      result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())
      assert result.errors == []
      state = result.state
      project = state.projects["authoring_insights_course"]
      section = state.sections["analytics_section_one"]

      question_id =
        state.activity_virtual_ids[{"authoring_insights_course", "analyzed_question"}].resource_id

      activity_type = ResourceType.id_for_activity()

      # Keep submission totals and historical attempts while making learner
      # evidence incomplete for one question in just one section.
      learners =
        from(s in ResourceSummary,
          where:
            s.section_id == ^section.id and s.user_id != -1 and
              s.resource_id == ^question_id and s.resource_type_id == ^activity_type
        )

      case @missing_evidence do
        :summary -> Repo.delete_all(learners)
        :correctness_counter -> Repo.update_all(learners, set: [num_correct: nil])
      end

      parents =
        from(s in ResourceSummary,
          where:
            s.section_id == ^section.id and s.user_id == -1 and
              s.resource_type_id != ^activity_type,
          select: {s.resource_type_id, s.resource_id}
        )
        |> Repo.all()

      for sections <- [[], [section.id]],
          {type, id} <- [{activity_type, question_id} | parents] do
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

        case type do
          ^activity_type ->
            assert is_nil(row.eventually_correct)

          _ ->
            assert_in_delta row.eventually_correct, row.num_correct / row.num_attempts, 0.000001
        end

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

  test "page and objective pagination ranks response accuracy across all matching resources" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())
    assert result.errors == []

    result =
      Scenarios.execute(
        [
          %VisitPageDirective{
            student: "alice",
            section: "analytics_section_one",
            page: "Unattempted Practice"
          },
          %AnswerQuestionDirective{
            student: "alice",
            section: "analytics_section_one",
            page: "Unattempted Practice",
            activity_virtual_id: "unattempted_question",
            response: "a"
          }
        ],
        RuntimeOpts.build(state: result.state)
      )

    assert result.errors == []

    state = result.state
    project_id = state.projects["authoring_insights_course"].project.id
    section_id = state.sections["analytics_section_one"].id

    for sections <- [[], [section_id]],
        type <- [ResourceType.id_for_page(), ResourceType.id_for_objective()] do
      options = %BrowseInsightsOptions{
        project_id: project_id,
        section_ids: sections,
        resource_type_id: type
      }

      [low] =
        BrowseInsights.browse_insights(
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :eventually_correct, direction: :asc},
          options
        )

      [high] =
        BrowseInsights.browse_insights(
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :eventually_correct, direction: :desc},
          options
        )

      [second] =
        BrowseInsights.browse_insights(
          %Paging{limit: 1, offset: 1},
          %Sorting{field: :eventually_correct, direction: :desc},
          options
        )

      assert low.total_count == 2
      assert high.total_count == 2
      assert low.eventually_correct == 0.0
      assert_in_delta high.eventually_correct, high.num_correct / high.num_attempts, 0.000001
      assert second.resource_id == low.resource_id
      assert second.eventually_correct == 0.0

      [filtered] =
        BrowseInsights.browse_insights(
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :eventually_correct, direction: :asc},
          %{options | text_search: high.title}
        )

      assert filtered.resource_id == high.resource_id
      assert filtered.total_count == 1
      assert filtered.eventually_correct == high.eventually_correct
    end

    question_id =
      state.activity_virtual_ids[{"authoring_insights_course", "analyzed_question"}].resource_id

    from(s in ResourceSummary,
      where: s.section_id == ^section_id and s.user_id != -1 and s.resource_id == ^question_id
    )
    |> Repo.delete_all()

    for sections <- [[], [section_id]],
        type <- [ResourceType.id_for_page(), ResourceType.id_for_objective()],
        direction <- [:asc, :desc] do
      [measured, unavailable] =
        BrowseInsights.browse_insights(
          %Paging{limit: 2, offset: 0},
          %Sorting{field: :eventually_correct, direction: direction},
          %BrowseInsightsOptions{
            project_id: project_id,
            section_ids: sections,
            resource_type_id: type
          }
        )

      for row <- [measured, unavailable] do
        assert_in_delta row.eventually_correct, row.num_correct / row.num_attempts, 0.000001
      end
    end
  end

  test "whole-question summaries require every scored part for each learner" do
    path = Path.join(__DIR__, "multipart_eventual_correctness.scenario.yaml")
    assert :ok = Scenarios.validate_file(path)
    result = Scenarios.execute_file(path, RuntimeOpts.build())
    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)

    state = result.state
    section = state.sections["multipart_section"]
    activity_id = state.activity_virtual_ids[{"multipart_eventual", "multi_input"}].resource_id
    [revision] = Oli.Publishing.DeliveryResolver.from_resource_id(section.slug, [activity_id])

    [counts] =
      EventualCorrectness.question_counts_query(nil, [section.id], %{
        activity_id => EventualCorrectness.required_part_ids(revision)
      })
      |> Repo.all()

    assert {counts.num_correct, counts.num_attempted} == {2, 3}

    page_id =
      Repo.one!(
        from(s in ResourceSummary,
          where:
            s.section_id == ^section.id and s.user_id == -1 and
              s.resource_type_id == ^ResourceType.id_for_page(),
          select: s.resource_id
        )
      )

    [page] = Oli.Publishing.DeliveryResolver.from_resource_id(section.slug, [page_id])
    students = Oli.Delivery.Sections.enrolled_students(section.slug, [:context_learner])

    [question] =
      OliWeb.Delivery.ActivityHelpers.summarize_activity_performance(
        section,
        page,
        Map.new(Oli.Activities.list_activity_registrations(), &{&1.id, &1}),
        students,
        [activity_id]
      )

    assert_in_delta question.all_attempt_pct, 2 / 3, 0.000001
  end
end
