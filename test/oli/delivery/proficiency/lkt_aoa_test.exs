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

    insert_state(section, user, low, aoa: 0.0, attempt_count: 3)
    insert_state(section, user, medium, aoa: 0.4, attempt_count: 3)
    insert_state(section, user, high, aoa: 0.800_001, attempt_count: 3)

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

  test "default proficiency cutoffs include 40 and 70 in Medium" do
    section = insert(:section, learning_model_version: :lkt_aoa)

    for {score, label} <- [
          {nil, "Not enough data"},
          {0.0, "Low"},
          {0.399999, "Low"},
          {0.4, "Medium"},
          {0.7, "Medium"},
          {0.700001, "High"},
          {1.0, "High"}
        ] do
      assert LktAoa.label_for_score(section, score, 3) == label
      assert LktAoa.label_for_score(section, score, 2) == "Not enough data"
    end
  end

  test "configured cutoffs apply to direct and parent estimates without changing naive or confidence buckets" do
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
    insert_state(section, user, child, aoa: 0.72, attempt_count: 3)

    assert {:ok, before} =
             LktAoa.estimates_for_objectives(section, [user.id], [child.id, parent.id], [])

    assert before[child.id][user.id].label == :high
    assert before[parent.id][user.id].label == :high

    original = Application.fetch_env!(:oli, :lkt_aoa)
    on_exit(fn -> Application.put_env(:oli, :lkt_aoa, original) end)

    Application.put_env(
      :oli,
      :lkt_aoa,
      Keyword.merge(original, low_medium_cutoff: 55.0, medium_high_cutoff: 85.0)
    )

    assert {:ok, after_change} =
             LktAoa.estimates_for_objectives(section, [user.id], [child.id, parent.id], [])

    for id <- [child.id, parent.id] do
      assert after_change[id][user.id].label == :medium

      assert Map.delete(after_change[id][user.id], :label) ==
               Map.delete(before[id][user.id], :label)
    end

    naive = %{section | learning_model_version: :naive}

    for {score, expected} <- [{0.4, "Low"}, {0.5, "Medium"}, {0.8, "Medium"}, {0.81, "High"}] do
      assert Oli.Delivery.Proficiency.label_for_score(naive, score) == expected
      assert Oli.Delivery.Metrics.confidence_label(score) == expected
    end
  end

  test "direct estimates preserve evidence but hide scores below three attempts" do
    section = insert(:section, learning_model_version: :lkt_aoa)
    user = insert(:user)
    objective = insert(:resource)

    insert_state(section, user, objective,
      aoa: 0.9,
      attempt_count: 2,
      unique_activity_part_count: 2
    )

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, [user.id], [objective.id], [])

    estimate = estimates[objective.id][user.id]
    assert estimate.score == nil
    assert estimate.label == :not_enough_information
    assert estimate.attempt_count == 2
    assert estimate.unique_activity_part_count == 2
    assert_in_delta estimate.confidence, 8 / 133, 1.0e-12
  end

  test "existing learner confidence uses current configuration without rewriting state" do
    section = insert(:section, learning_model_version: :lkt_aoa)
    user = insert(:user)
    objective = insert(:resource)

    state =
      insert_state(section, user, objective, attempt_count: 8, unique_activity_part_count: 5)

    original_config = Application.fetch_env!(:oli, :lkt_aoa)
    on_exit(fn -> Application.put_env(:oli, :lkt_aoa, original_config) end)

    assert {:ok, before} =
             LktAoa.estimates_for_objectives(section, [user.id], [objective.id], [])

    assert_in_delta before[objective.id][user.id].confidence, 0.5, 1.0e-12

    for {midpoint, steepness, expected} <- [{10.0, 3.0, 1 / 9}, {10.0, 2.0, 0.2}] do
      Application.put_env(
        :oli,
        :lkt_aoa,
        Keyword.merge(original_config,
          confidence_midpoint: midpoint,
          confidence_steepness: steepness
        )
      )

      assert {:ok, after_change} =
               LktAoa.estimates_for_objectives(section, [user.id], [objective.id], [])

      assert_in_delta after_change[objective.id][user.id].confidence, expected, 1.0e-12

      assert Map.delete(after_change[objective.id][user.id], :confidence) ==
               Map.delete(before[objective.id][user.id], :confidence)
    end

    assert Oli.Repo.get_by!(LearningState,
             section_id: section.id,
             user_id: user.id,
             learning_objective_id: objective.id
           ) == state
  end

  test "parents weight all child attempts once one child reaches three" do
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

    insert_state(section, user, child_a,
      aoa: 0.2,
      attempt_count: 1,
      unique_activity_part_count: 1
    )

    insert_state(section, user, child_b,
      aoa: 0.8,
      attempt_count: 3,
      unique_activity_part_count: 3
    )

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, [user.id], [parent.id], [])

    estimate = estimates[parent.id][user.id]
    assert_in_delta estimate.score, 0.65, 1.0e-12
    assert_in_delta estimate.confidence, (1 / 126 + 3 * (27 / 152)) / 4, 1.0e-12
    assert estimate.attempt_count == 4
    assert estimate.label == :medium
  end

  test "parents require three attempts on a child and never prefer a parent state row" do
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
    insert_state(section, user, child, aoa: 0.3, attempt_count: 2, unique_activity_part_count: 2)

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, [user.id], [parent.id], [])

    estimate = estimates[parent.id][user.id]
    assert estimate.score == nil
    assert estimate.attempt_count == 2
    assert estimate.label == :not_enough_information
  end

  test "parent eligibility requires one child with three attempts and governs class reporting" do
    section =
      insert(:section,
        learning_model_version: :lkt_aoa,
        section_resource_migration_version: SectionResourceMigration.current_version()
      )

    project = insert(:project)
    parent = insert(:resource)
    children = Enum.map(1..3, fn _ -> insert(:resource) end)
    child_srs = Enum.map(children, &objective_section_resource(section, project, &1))
    objective_section_resource(section, project, parent, children: Enum.map(child_srs, & &1.id))

    cases = [
      {[1, 1, 1], :not_enough_information},
      {[2, 2, 0], :not_enough_information},
      {[3, 0, 0], :high},
      {[3, 2, 0], :high},
      {[0, 0, 0], :not_enough_information}
    ]

    users =
      Enum.map(cases, fn {counts, _label} ->
        user = insert(:user)

        for {child, count} <- Enum.zip(children, counts), count > 0 do
          insert_state(section, user, child,
            aoa: 0.9,
            attempt_count: count,
            unique_activity_part_count: count
          )
        end

        user
      end)

    user_ids = Enum.map(users, & &1.id)

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, user_ids, [parent.id], [])

    for {user, {counts, expected_label}} <- Enum.zip(users, cases) do
      estimate = estimates[parent.id][user.id]
      assert estimate.label == expected_label
      assert estimate.attempt_count == Enum.sum(counts)

      case expected_label do
        :not_enough_information -> assert estimate.score == nil
        :high -> assert_in_delta estimate.score, 0.9, 1.0e-12
      end
    end

    assert {:ok, aggregates} =
             LktAoa.objective_aggregates(section, [parent.id], user_ids: user_ids)

    aggregate = aggregates[parent.id]
    assert aggregate.distribution == %{high: 2, not_enough_information: 3}
    assert aggregate.contributing_count == 2
    assert aggregate.coverage == %{defined: 2, total: 5}
    assert_in_delta aggregate.numeric_score, 0.9, 1.0e-12
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

  test "parents with evidence only on their children still report their learners" do
    section =
      insert(:section,
        learning_model_version: :lkt_aoa,
        section_resource_migration_version: SectionResourceMigration.current_version()
      )

    user = insert(:user)
    project = insert(:project)
    [parent | children] = Enum.map(1..4, fn _ -> insert(:resource) end)
    child_srs = Enum.map(children, &objective_section_resource(section, project, &1))
    objective_section_resource(section, project, parent, children: Enum.map(child_srs, & &1.id))

    Enum.each(children, &insert_state(section, user, &1, aoa: 0.67, attempt_count: 3))

    assert {:ok, [user_id]} = LktAoa.user_ids_for_objectives(section, [parent.id])
    assert user_id == user.id

    assert {:ok, estimates} =
             LktAoa.estimates_for_objectives(section, [user_id], [parent.id], [])

    assert_in_delta estimates[parent.id][user.id].score, 0.67, 1.0e-12
    assert estimates[parent.id][user.id].label == :medium
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
    defaults = [aoa: 0.0, attempt_count: 0, unique_activity_part_count: 0]

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
