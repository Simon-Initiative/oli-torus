defmodule Oli.Analytics.Summary.EventualCorrectnessTest do
  use Oli.DataCase

  alias Oli.Analytics.Summary
  alias Oli.Analytics.Summary.{BrowseInsights, BrowseInsightsOptions, ResourceSummary}
  alias Oli.Analytics.Summary.EventualCorrectness
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}

  setup do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_activity(%{title: "Question", content: %{}}, :question)
      |> Seeder.add_user(%{}, :alice)
      |> Seeder.add_user(%{}, :bob)

    Seeder.publish_project(map)
  end

  test "historical successes survive wrong retries and repeated successes count once", ctx do
    # Alice was correct on her first try, then submitted nine wrong answers.
    # Bob was initially wrong, then answered correctly seven times.
    alice = summary(ctx, ctx.alice.id, 1, 10, 1)
    bob = summary(ctx, ctx.bob.id, 7, 8, 0)
    aggregate_summaries(ctx, 8, 18, 1)

    for sections <- [[], [ctx.section.id]] do
      row = insight(ctx, sections)
      assert row.eventually_correct == 1.0
      assert row.first_attempt_correct == 0.5
      assert row.num_correct == 8
      assert row.num_attempts == 18
    end

    # Only the old counters change: no rebuild or new pipeline processing occurs.
    alice |> Ecto.Changeset.change(num_attempts: 20) |> Repo.update!()
    bob |> Ecto.Changeset.change(num_attempts: 30) |> Repo.update!()

    assert insight(ctx, []).eventually_correct == 1.0

    {:ok, response} =
      Summary.create_resource_part_response(%{
        resource_id: ctx.question.resource.id,
        part_id: "part1",
        response: "correct",
        label: "Correct"
      })

    {:ok, _} =
      Summary.create_response_summary(%{
        section_id: ctx.section.id,
        page_id: ctx.page1.id,
        activity_id: ctx.question.resource.id,
        part_id: "part1",
        resource_part_response_id: response.id,
        count: 8
      })

    [summary] =
      Summary.summarize_activities_for_page(ctx.section.id, ctx.page1.id, [
        ctx.question.resource.id
      ])

    assert summary.num_eventually_correct == 2
    assert summary.num_eventually_attempted == 2
    assert summary.num_correct == 8
    assert summary.num_attempts == 18
  end

  test "unsuccessful learners count once regardless of retries", ctx do
    summary(ctx, ctx.alice.id, 7, 7, 1)
    summary(ctx, ctx.bob.id, 0, 20, 0)
    aggregate_summaries(ctx, 7, 27, 1)

    for sections <- [[], [ctx.section.id]] do
      assert insight(ctx, sections).eventually_correct == 0.5
    end
  end

  test "section filters preserve separate enrollment opportunities", ctx do
    summary(ctx, ctx.alice.id, 1, 10, 1)
    summary(ctx, ctx.bob.id, 0, 20, 0)
    aggregate_summaries(ctx, 1, 30, 1)

    second = Seeder.create_section(ctx)
    summary(second, ctx.alice.id, 0, 12, 0)
    # The second section also needs the existing section-wide counters.
    Repo.insert!(%ResourceSummary{
      section_id: second.section.id,
      resource_id: ctx.question.resource.id,
      resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
      part_id: "part1",
      num_attempts: 12,
      num_first_attempts: 1
    })

    assert insight(ctx, []).eventually_correct == 1 / 3
    assert insight(ctx, [ctx.section.id]).eventually_correct == 0.5
    assert insight(ctx, [ctx.section.id, second.section.id]).eventually_correct == 1 / 3
    assert insight(ctx, [second.section.id]).eventually_correct == 0.0
  end

  test "missing student evidence does not fall back to submission accuracy", ctx do
    aggregate_summaries(ctx, 8, 18, 1)
    assert insight(ctx, []).eventually_correct == nil
  end

  test "a rollup is unavailable when any attempted part lacks learner evidence" do
    assert EventualCorrectness.rate([{1, 2}, {nil, nil}]) == nil
    assert EventualCorrectness.rate([{nil, nil}]) == nil
    assert EventualCorrectness.rate([]) == nil
    assert EventualCorrectness.rate([{0, 2}, {0, 1}]) == 0.0
    assert EventualCorrectness.rate([{1, 2}, {1, 1}]) == 2 / 3
  end

  test "sorting and paging use learner success rather than submission accuracy", ctx do
    summary(ctx, ctx.alice.id, 7, 7, 1)
    summary(ctx, ctx.bob.id, 0, 1, 0)
    aggregate_summaries(ctx, 7, 8, 1)

    summary(ctx, ctx.alice.id, 1, 10, 0, "part2")
    summary(ctx, ctx.bob.id, 1, 10, 0, "part2")
    aggregate_summaries(ctx, 2, 20, 0, "part2")

    for sections <- [[], [ctx.section.id]] do
      [row] =
        BrowseInsights.browse_insights(
          %Paging{limit: 1, offset: 0},
          %Sorting{field: :eventually_correct, direction: :desc},
          %BrowseInsightsOptions{
            project_id: ctx.project.id,
            section_ids: sections,
            resource_type_id: Oli.Resources.ResourceType.id_for_activity()
          }
        )

      assert row.part_id == "part2"
      assert row.eventually_correct == 1.0
      assert row.total_count == 2
    end
  end

  test "project-wide results exclude other projects' sections", ctx do
    summary(ctx, ctx.alice.id, 1, 10, 1)
    summary(ctx, ctx.bob.id, 1, 10, 0)
    aggregate_summaries(ctx, 2, 20, 1)

    foreign = Seeder.base_project_with_resource2() |> Seeder.create_section()
    summary(%{ctx | section: foreign.section}, ctx.alice.id, 0, 50, 0)

    assert insight(ctx, []).eventually_correct == 1.0
  end

  test "unavailable activity rates sort after measured rates in either direction", ctx do
    summary(ctx, ctx.alice.id, 1, 2, 1)
    summary(ctx, ctx.bob.id, 0, 2, 0)
    aggregate_summaries(ctx, 1, 4, 1)
    aggregate_summaries(ctx, 0, 4, 0, "missing")

    for sections <- [[], [ctx.section.id]], direction <- [:asc, :desc] do
      [measured, missing] =
        BrowseInsights.browse_insights(
          %Paging{limit: 2, offset: 0},
          %Sorting{field: :eventually_correct, direction: direction},
          %BrowseInsightsOptions{
            project_id: ctx.project.id,
            section_ids: sections,
            resource_type_id: Oli.Resources.ResourceType.id_for_activity()
          }
        )

      assert measured.eventually_correct == 0.5
      assert is_nil(missing.eventually_correct)
      assert missing.part_id == "missing"
    end
  end

  test "section counts ignore records that do not use the section scope sentinel", ctx do
    summary(ctx, ctx.alice.id, 1, 2, 1)
    aggregate_summaries(ctx, 1, 2, 1)

    Repo.insert!(%ResourceSummary{
      project_id: ctx.project.id,
      section_id: ctx.section.id,
      resource_id: ctx.question.resource.id,
      resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
      part_id: "foreign_scope",
      num_attempts: 10
    })

    [row] = EventualCorrectness.counts_query(ctx.project.id, [ctx.section.id]) |> Repo.all()
    assert row.part_id == "part1"
    assert row.num_correct == 1
    assert row.num_attempted == 1
    assert insight(ctx, [ctx.section.id]).eventually_correct == 1.0
  end

  defp summary(ctx, user_id, correct, attempts, first_correct, part_id \\ "part1") do
    {:ok, row} =
      Summary.create_resource_summary(%{
        section_id: ctx.section.id,
        user_id: user_id,
        resource_id: ctx.question.resource.id,
        resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
        part_id: part_id,
        num_correct: correct,
        num_attempts: attempts,
        num_first_attempts: 1,
        num_first_attempts_correct: first_correct
      })

    row
  end

  defp aggregate_summaries(ctx, correct, attempts, first_correct, part_id \\ "part1") do
    for {project_id, section_id} <- [{ctx.project.id, -1}, {-1, ctx.section.id}] do
      Repo.insert!(%ResourceSummary{
        project_id: project_id,
        section_id: section_id,
        resource_id: ctx.question.resource.id,
        resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
        part_id: part_id,
        num_correct: correct,
        num_attempts: attempts,
        num_first_attempts: 2,
        num_first_attempts_correct: first_correct
      })
    end
  end

  defp insight(ctx, sections) do
    [row] =
      BrowseInsights.browse_insights(
        %Paging{limit: 10, offset: 0},
        %Sorting{field: :eventually_correct, direction: :desc},
        %BrowseInsightsOptions{
          project_id: ctx.project.id,
          section_ids: sections,
          resource_type_id: Oli.Resources.ResourceType.id_for_activity()
        }
      )

    row
  end
end
