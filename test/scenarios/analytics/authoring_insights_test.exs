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

    test "missing #{missing_evidence} makes activity and parent rollups unavailable" do
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

  test "page and objective pagination ranks eventual correctness across all matching resources" do
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
      assert high.eventually_correct == 0.5
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
      assert filtered.eventually_correct == 0.5
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

      assert measured.eventually_correct == 0.0
      assert is_nil(unavailable.eventually_correct)
    end
  end

  test "malformed legacy objective JSON cannot crash objective analytics" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())
    assert result.errors == []
    state = result.state
    project_id = state.projects["authoring_insights_course"].project.id
    section_id = state.sections["analytics_section_one"].id

    question_id =
      state.activity_virtual_ids[{"authoring_insights_course", "analyzed_question"}].resource_id

    bindings =
      Repo.one!(
        from(r in Oli.Resources.Revision,
          where: r.resource_id == ^question_id,
          select: r.objectives,
          limit: 1
        )
      )

    [{part_id, [objective_id]}] = Map.to_list(bindings)

    mixed = [
      objective_id,
      "garbage",
      "9223372036854775808",
      9_223_372_036_854_775_807,
      String.duplicate("9", 100),
      "1.5",
      true,
      nil,
      %{},
      [],
      0,
      -1
    ]

    corruptions = [
      %{part_id => mixed, "malformed_part" => "not-an-array"},
      %{part_id => [Integer.to_string(objective_id)]},
      %{part_id => "not-an-array"},
      mixed,
      nil,
      42,
      "not-an-object"
    ]

    for objectives <- corruptions do
      # Simulate already persisted legacy/corrupt data without bypassing the
      # write validation for new authored content in production.
      Repo.query!("UPDATE revisions SET objectives = $1::text::jsonb WHERE resource_id = $2", [
        Jason.encode!(objectives),
        question_id
      ])

      for ids <- [nil, [objective_id]] do
        rows =
          EventualCorrectness.counts_query(
            project_id,
            [section_id],
            ResourceType.id_for_objective(),
            resource_ids: ids
          )
          |> Repo.all()

        assert Enum.any?(rows, &(&1.resource_id == objective_id))
      end

      [row] =
        BrowseInsights.browse_insights(
          %Paging{limit: 10, offset: 0},
          %Sorting{field: :eventually_correct, direction: :desc},
          %BrowseInsightsOptions{
            project_id: project_id,
            section_ids: [section_id],
            resource_type_id: ResourceType.id_for_objective(),
            resource_id: objective_id
          }
        )

      assert row.resource_id == objective_id

      case objectives do
        %{^part_id => ids} when is_list(ids) -> assert row.eventually_correct == 0.5
        _ -> :ok
      end
    end
  end
end
