defmodule Oli.Delivery.Proficiency.LktAoaTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Proficiency.LktAoa
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.LearningModel.LearningState
  alias Oli.Resources.ResourceType

  test "distinguishes missing state from a valid zero and applies LKT boundaries" do
    section = insert(:section, learning_model_version: :lkt_aoa)
    user = insert(:user)
    [missing, low, medium, high] = Enum.map(1..4, fn _ -> insert(:resource) end)

    insert_state(section, user, low, aoa: 0.0, attempt_count: 3, confidence: 0.4)
    insert_state(section, user, medium, aoa: 0.4, attempt_count: 3, confidence: 0.5)
    insert_state(section, user, high, aoa: 0.800_001, attempt_count: 3, confidence: 0.6)

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(
               section,
               [user.id],
               [missing.id, low.id, medium.id, high.id],
               []
             )

    assert estimates[missing.id][user.id].score == nil
    assert estimates[missing.id][user.id].label == :not_enough_information
    assert estimates[low.id][user.id].score == 0.0
    assert estimates[low.id][user.id].label == :low
    assert estimates[medium.id][user.id].label == :medium
    assert estimates[high.id][user.id].label == :high
  end

  test "direct estimates preserve evidence but hide scores below three attempts" do
    section = insert(:section, learning_model_version: :lkt_aoa)
    user = insert(:user)
    objective = insert(:resource)

    insert_state(section, user, objective,
      aoa: 0.9,
      attempt_count: 2,
      unique_activity_part_count: 2,
      confidence: 0.7
    )

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, [user.id], [objective.id], [])

    estimate = estimates[objective.id][user.id]
    assert estimate.score == nil
    assert estimate.label == :not_enough_information
    assert estimate.attempt_count == 2
    assert estimate.unique_activity_part_count == 2
    assert estimate.confidence == 0.7
  end

  test "parents weight children by total attempt count without a per-child minimum" do
    section =
      insert(:section,
        learning_model_version: :lkt_aoa,
        section_resource_migration_version: SectionResourceMigration.current_version()
      )

    user = insert(:user)
    project = insert(:project)
    [parent, child_a, child_b] = Enum.map(1..3, fn _ -> insert(:resource) end)

    child_a_sr = objective_section_resource(section, project, child_a)
    child_b_sr = objective_section_resource(section, project, child_b)

    objective_section_resource(section, project, parent, children: [child_a_sr.id, child_b_sr.id])

    insert_state(section, user, child_a, aoa: 0.2, attempt_count: 1, confidence: 0.2)
    insert_state(section, user, child_b, aoa: 0.8, attempt_count: 3, confidence: 0.8)

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, [user.id], [parent.id], [])

    estimate = estimates[parent.id][user.id]
    assert_in_delta estimate.score, 0.65, 1.0e-12
    assert_in_delta estimate.confidence, 0.65, 1.0e-12
    assert estimate.attempt_count == 4
    assert estimate.label == :medium
  end

  test "parents require three attempts in total and never prefer a parent state row" do
    section =
      insert(:section,
        learning_model_version: :lkt_aoa,
        section_resource_migration_version: SectionResourceMigration.current_version()
      )

    user = insert(:user)
    project = insert(:project)
    [parent, child] = Enum.map(1..2, fn _ -> insert(:resource) end)
    child_sr = objective_section_resource(section, project, child)
    objective_section_resource(section, project, parent, children: [child_sr.id])

    insert_state(section, user, parent, aoa: 1.0, attempt_count: 10)
    insert_state(section, user, child, aoa: 0.3, attempt_count: 2, confidence: 0.3)

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, [user.id], [parent.id], [])

    estimate = estimates[parent.id][user.id]
    assert estimate.score == nil
    assert estimate.attempt_count == 2
    assert estimate.label == :not_enough_information
  end

  test "parent children prefer SectionResource IDs when resource-ID values collide" do
    section =
      insert(:section,
        learning_model_version: :lkt_aoa,
        section_resource_migration_version: SectionResourceMigration.current_version()
      )

    user = insert(:user)
    project = insert(:project)
    parent = insert(:resource)
    intended_child = insert(:resource)
    collision_id = 1_500_000_000 + System.unique_integer([:positive])
    colliding_resource = insert(:resource, id: collision_id)

    intended_child_sr =
      objective_section_resource(section, project, intended_child, id: collision_id)

    objective_section_resource(section, project, colliding_resource)
    objective_section_resource(section, project, parent, children: [intended_child_sr.id])

    insert_state(section, user, intended_child, aoa: 0.9, attempt_count: 3)
    insert_state(section, user, colliding_resource, aoa: 0.1, attempt_count: 3)

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, [user.id], [parent.id], [])

    assert estimates[parent.id][user.id].score == 0.9
  end

  test "uses one learning-state query for bulk identities and never reads attempt summaries" do
    section = insert(:section, learning_model_version: :lkt_aoa)
    users = Enum.map(1..3, fn _ -> insert(:user) end)
    objectives = Enum.map(1..4, fn _ -> insert(:resource) end)

    for user <- users, objective <- objectives do
      insert_state(section, user, objective, aoa: 0.5, attempt_count: 3)
    end

    queries =
      capture_queries(fn ->
        assert {:ok, _estimates} =
                 LktAoa.estimates_for_objectives(
                   section,
                   Enum.map(users, & &1.id),
                   Enum.map(objectives, & &1.id),
                   []
                 )
      end)

    assert Enum.count(queries, &String.contains?(&1, ~s(FROM "learning_states"))) == 1
    refute Enum.any?(queries, &Regex.match?(~r/FROM \"resource_summaries\"/, &1))

    refute Enum.any?(queries, fn query ->
             Regex.match?(~r/FROM \"(?:part|activity|resource)_attempts\"/, query)
           end)
  end

  test "direct and parent query counts stay constant as identity cardinality grows" do
    section =
      insert(:section,
        learning_model_version: :lkt_aoa,
        section_resource_migration_version: SectionResourceMigration.current_version()
      )

    project = insert(:project)
    users = Enum.map(1..4, fn _ -> insert(:user) end)
    direct_objectives = Enum.map(1..4, fn _ -> insert(:resource) end)
    parent = insert(:resource)

    child_section_resources =
      Enum.map(direct_objectives, &objective_section_resource(section, project, &1))

    objective_section_resource(section, project, parent,
      children: Enum.map(child_section_resources, & &1.id)
    )

    for user <- users, objective <- direct_objectives do
      insert_state(section, user, objective, aoa: 0.5, attempt_count: 3)
    end

    # Initialize the depot before measuring provider reads so the assertion
    # compares steady-state query work rather than one-time JIT initialization.
    SectionResourceDepot.objectives(section.id)

    small_direct =
      capture_queries(fn ->
        LktAoa.estimates_for_objectives(section, [hd(users).id], [hd(direct_objectives).id], [])
      end)

    large_direct =
      capture_queries(fn ->
        LktAoa.estimates_for_objectives(
          section,
          Enum.map(users, & &1.id),
          Enum.map(direct_objectives, & &1.id),
          []
        )
      end)

    small_parent =
      capture_queries(fn ->
        LktAoa.estimates_for_objectives(section, [hd(users).id], [parent.id], [])
      end)

    large_parent =
      capture_queries(fn ->
        LktAoa.estimates_for_objectives(section, Enum.map(users, & &1.id), [parent.id], [])
      end)

    assert query_count(small_direct) == query_count(large_direct)
    assert query_count(small_direct) == 1
    refute Enum.any?(small_direct, &String.contains?(&1, ~s(FROM "revisions")))
    assert query_count(small_parent) == query_count(large_parent)
    assert query_count(small_parent) == 1
  end

  defp objective_section_resource(section, project, resource, attrs \\ []) do
    revision =
      insert(:revision,
        resource: resource,
        resource_type_id: ResourceType.id_for_objective()
      )

    insert(
      :section_resource,
      Keyword.merge(
        [
          section: section,
          project: project,
          resource_id: resource.id,
          resource_type_id: ResourceType.id_for_objective(),
          revision_id: revision.id
        ],
        attrs
      )
    )
  end

  defp insert_state(section, user, objective, attrs) do
    defaults = [aoa: 0.0, attempt_count: 0, unique_activity_part_count: 0, confidence: 0.0]

    struct!(
      LearningState,
      Keyword.merge(
        [section_id: section.id, user_id: user.id, learning_objective_id: objective.id],
        Keyword.merge(defaults, attrs)
      )
    )
    |> Oli.Repo.insert!()
  end

  defp capture_queries(fun) do
    handler_id = "proficiency-query-count-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:oli, :repo, :query],
        fn _event, _measurements, metadata, _config ->
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

  defp query_count(queries), do: Enum.count(queries, &String.starts_with?(&1, "SELECT"))
end
