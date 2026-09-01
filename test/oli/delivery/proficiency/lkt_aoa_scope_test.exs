defmodule Oli.Delivery.Proficiency.LktAoaScopeTest do
  use Oli.DataCase

  import Ecto.Query
  import Oli.Factory

  alias Oli.Delivery.Proficiency.LktAoa
  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.LearningModel.LearningState
  alias Oli.Resources.ResourceType

  defmodule UnavailableDepotCoordinator do
    def init_if_necessary(_desc, _section_id, _caller), do: {:error, :jit_failed}
  end

  test "scope eligibility uses total attempts and equally weights distinct available objectives" do
    %{section: section, page: page, objectives: [objective_a, objective_b, _missing]} =
      scope_fixture()

    user = insert(:user)

    insert_state(section, user, objective_a, aoa: 0.2, attempt_count: 1)
    insert_state(section, user, objective_b, aoa: 0.8, attempt_count: 2)

    assert {:ok, estimates} =
             LktAoa.estimates_for_scopes(section, [user.id], [{:page, page.resource_id}], [])

    estimate = estimates[{:page, page.resource_id}][user.id]
    assert_in_delta estimate.score, 0.5, 1.0e-12
    assert estimate.label == :medium
    assert estimate.attempt_count == 3
    assert estimate.unique_activity_part_count == 0
  end

  test "fewer than three total attempts hides the scope score" do
    %{section: section, page: page, objectives: [objective | _]} = scope_fixture()
    user = insert(:user)
    insert_state(section, user, objective, aoa: 0.9, attempt_count: 2)

    assert {:ok, estimates} =
             LktAoa.estimates_for_scopes(section, [user.id], [{:page, page.resource_id}], [])

    estimate = estimates[{:page, page.resource_id}][user.id]
    assert estimate.score == nil
    assert estimate.label == :not_enough_information
    assert estimate.attempt_count == 2
  end

  test "class aggregation equally weights defined learners and retains unavailable learners" do
    %{section: section, page: page, objectives: [objective | _]} = scope_fixture()
    [low, high, unavailable] = Enum.map(1..3, fn _ -> insert(:user) end)
    insert_state(section, low, objective, aoa: 0.2, attempt_count: 3)
    insert_state(section, high, objective, aoa: 0.8, attempt_count: 30)
    insert_state(section, unavailable, objective, aoa: 1.0, attempt_count: 2)

    assert {:ok, aggregates} =
             LktAoa.scope_aggregates(section, [{:page, page.resource_id}],
               user_ids: [low.id, high.id, unavailable.id]
             )

    aggregate = aggregates[{:page, page.resource_id}]
    assert_in_delta aggregate.numeric_score, 0.5, 1.0e-12
    assert aggregate.contributing_count == 2
    assert aggregate.total_count == 3
    assert aggregate.distribution == %{low: 1, medium: 1, not_enough_information: 1}
  end

  test "page label ties preserve the legacy proficiency ordering" do
    %{section: section, page: page, objectives: [objective | _]} = scope_fixture()
    [low, medium] = Enum.map(1..2, fn _ -> insert(:user) end)
    page_id = page.resource_id
    insert_state(section, low, objective, aoa: 0.2, attempt_count: 3)
    insert_state(section, medium, objective, aoa: 0.6, attempt_count: 3)

    assert {:ok, %{^page_id => "Low"}} =
             LktAoa.labels_for_pages(section, [page_id], [low.id, medium.id])
  end

  test "one state query serves growing learner and objective sets" do
    %{section: section, page: page, objectives: objectives} = scope_fixture()
    users = Enum.map(1..3, fn _ -> insert(:user) end)

    for user <- users, objective <- objectives do
      insert_state(section, user, objective, aoa: 0.5, attempt_count: 3)
    end

    queries =
      capture_queries(fn ->
        assert {:ok, _} =
                 LktAoa.estimates_for_scopes(
                   section,
                   Enum.map(users, & &1.id),
                   [{:page, page.resource_id}, :course],
                   []
                 )
      end)

    assert Enum.count(queries, &String.contains?(&1, ~s(FROM "learning_states"))) == 1
    refute Enum.any?(queries, &String.contains?(&1, ~s(FROM "resource_summaries")))
  end

  test "depot failure returns unavailable without querying state or falling back to naive" do
    section = insert(:section, learning_model_version: :lkt_aoa)
    user = insert(:user)
    previous = Application.get_env(:oli, :depot_coordinator)
    Application.put_env(:oli, :depot_coordinator, UnavailableDepotCoordinator)
    on_exit(fn -> Application.put_env(:oli, :depot_coordinator, previous) end)

    queries =
      capture_queries(fn ->
        assert {:error, {:scope_membership_unavailable, :jit_failed}} =
                 LktAoa.estimates_for_scopes(section, [user.id], [:course], [])
      end)

    refute Enum.any?(queries, &String.contains?(&1, ~s(FROM "learning_states")))
    refute Enum.any?(queries, &String.contains?(&1, ~s(FROM "resource_summaries")))
  end

  defp scope_fixture do
    section =
      insert(:section,
        learning_model_version: :lkt_aoa,
        section_resource_migration_version: SectionResourceMigration.current_version()
      )

    project = insert(:project)
    activities = Enum.map(1..3, fn _ -> insert(:resource) end)

    objectives =
      Enum.zip(activities, Enum.map(1..3, fn _ -> insert(:resource) end))
      |> Enum.map(fn {activity, objective} ->
        sr(section, project, objective, ResourceType.id_for_objective(),
          related_activities: [activity.id]
        )
      end)

    page =
      sr(section, project, insert(:resource), ResourceType.id_for_page(),
        related_activities: Enum.map(activities, & &1.id)
      )

    root =
      sr(section, project, insert(:resource), ResourceType.id_for_container(),
        children: [page.id]
      )

    {1, nil} =
      Oli.Repo.update_all(
        from(s in Oli.Delivery.Sections.Section, where: s.id == ^section.id),
        set: [root_section_resource_id: root.id]
      )

    %{
      section: %{section | root_section_resource_id: root.id},
      page: page,
      objectives: objectives
    }
  end

  defp sr(section, project, resource, type_id, attrs) do
    revision = insert(:revision, resource: resource, resource_type_id: type_id)

    insert(
      :section_resource,
      Keyword.merge(
        [
          section: section,
          project: project,
          resource_id: resource.id,
          resource_type_id: type_id,
          revision_id: revision.id
        ],
        attrs
      )
    )
  end

  defp insert_state(section, user, objective, attrs) do
    struct!(
      LearningState,
      Keyword.merge(
        [
          section_id: section.id,
          user_id: user.id,
          learning_objective_id: objective.resource_id,
          aoa: 0.0,
          attempt_count: 0,
          unique_activity_part_count: 0,
          confidence: 0.0
        ],
        attrs
      )
    )
    |> Oli.Repo.insert!()
  end

  defp capture_queries(fun) do
    handler_id = "scope-query-count-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          send(parent, {:repo_query, metadata.query || ""})
        end,
        nil
      )

    try do
      fun.()
    after
      :telemetry.detach(handler_id)
    end

    collect_queries([])
  end

  defp collect_queries(queries) do
    receive do
      {:repo_query, query} -> collect_queries([query | queries])
    after
      0 -> queries
    end
  end
end
