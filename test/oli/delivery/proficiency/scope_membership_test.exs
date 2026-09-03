defmodule Oli.Delivery.Proficiency.ScopeMembershipTest do
  use Oli.DataCase

  import Oli.Factory
  import Ecto.Query

  alias Oli.Delivery.Proficiency.ScopeMembership
  alias Oli.Delivery.Sections.{SectionResourceDepot, SectionResourceMigration}
  alias Oli.Resources.ResourceType

  defmodule UnavailableDepotCoordinator do
    def init_if_necessary(_desc, _section_id, _caller), do: {:error, :jit_failed}
  end

  test "derives deduplicated page, descendant container, and course membership from the depot" do
    %{
      section: section,
      page_a: page_a,
      page_b: page_b,
      container: container,
      objectives: objectives
    } =
      scope_fixture()

    assert {:ok, membership} =
             ScopeMembership.objectives_for_scopes(section, [
               {:page, page_a.resource_id},
               {:page, page_b.resource_id},
               {:container, container.resource_id},
               :course
             ])

    [objective_a, objective_b, direct_only] = objectives

    assert membership[{:page, page_a.resource_id}] ==
             MapSet.new([objective_a.resource_id, objective_b.resource_id])

    assert membership[{:page, page_b.resource_id}] ==
             MapSet.new([objective_a.resource_id, objective_b.resource_id])

    assert membership[{:container, container.resource_id}] ==
             MapSet.new([objective_a.resource_id, objective_b.resource_id])

    assert membership[:course] == MapSet.new([objective_a.resource_id, objective_b.resource_id])
    refute MapSet.member?(membership[:course], direct_only.resource_id)
  end

  test "a projected page with no activities has valid empty membership" do
    %{section: section, empty_page: empty_page} = scope_fixture()

    assert {:ok, membership} =
             ScopeMembership.objectives_for_scopes(section, [{:page, empty_page.resource_id}])

    assert membership[{:page, empty_page.resource_id}] == MapSet.new()
  end

  test "membership performs no database query after depot initialization" do
    %{section: section, page_a: page_a} = scope_fixture()
    SectionResourceDepot.proficiency_resources(section.id)

    queries =
      capture_queries(fn ->
        assert {:ok, _membership} =
                 ScopeMembership.objectives_for_scopes(section, [{:page, page_a.resource_id}])
      end)

    assert queries == []
  end

  test "missing requested resources fail closed instead of looking like empty pages" do
    %{section: section, objectives: [objective | _], page_a: page} = scope_fixture()

    assert {:error, {:scope_membership_unavailable, {:missing_scope_resource, {:page, 999_999}}}} =
             ScopeMembership.objectives_for_scopes(section, [{:page, 999_999}])

    assert {:error, {:scope_membership_unavailable, {:missing_scope_resource, wrong_scope}}} =
             ScopeMembership.objectives_for_scopes(section, [
               {:page, objective.resource_id},
               {:container, page.resource_id}
             ])

    assert wrong_scope in [{:page, objective.resource_id}, {:container, page.resource_id}]

    stale_root = %{section | root_section_resource_id: 999_999}

    assert {:error, {:scope_membership_unavailable, {:missing_scope_resource, :course}}} =
             ScopeMembership.objectives_for_scopes(stale_root, [:course])
  end

  test "depot initialization failures are returned explicitly" do
    section = insert(:section, learning_model_version: :lkt_aoa)
    previous = Application.get_env(:oli, :depot_coordinator)
    Application.put_env(:oli, :depot_coordinator, UnavailableDepotCoordinator)
    on_exit(fn -> Application.put_env(:oli, :depot_coordinator, previous) end)

    assert {:error, {:scope_membership_unavailable, :jit_failed}} =
             ScopeMembership.objectives_for_scopes(section, [:course])
  end

  defp scope_fixture do
    section =
      insert(:section,
        learning_model_version: :lkt_aoa,
        section_resource_migration_version: SectionResourceMigration.current_version()
      )

    project = insert(:project)
    activity_a = insert(:resource)
    activity_b = insert(:resource)

    [objective_a, objective_b, direct_only] =
      Enum.map(1..3, fn _ ->
        resource = insert(:resource)

        sr(section, project, resource, ResourceType.id_for_objective())
      end)

    objective_a =
      Oli.Repo.update!(Ecto.Changeset.change(objective_a, related_activities: [activity_a.id]))

    objective_b =
      Oli.Repo.update!(
        Ecto.Changeset.change(objective_b, related_activities: [activity_a.id, activity_b.id])
      )

    page_a_resource = insert(:resource)
    page_b_resource = insert(:resource)
    empty_page_resource = insert(:resource)

    page_a =
      sr(section, project, page_a_resource, ResourceType.id_for_page(),
        related_activities: [activity_a.id, activity_a.id, activity_b.id],
        objectives: %{direct_only.resource_id => 1}
      )

    page_b =
      sr(section, project, page_b_resource, ResourceType.id_for_page(),
        related_activities: [activity_a.id]
      )

    empty_page = sr(section, project, empty_page_resource, ResourceType.id_for_page())
    container_resource = insert(:resource)

    container =
      sr(section, project, container_resource, ResourceType.id_for_container(),
        children: [page_a.id, page_b.id]
      )

    root_resource = insert(:resource)

    root =
      sr(section, project, root_resource, ResourceType.id_for_container(),
        children: [container.id, empty_page.id]
      )

    {1, nil} =
      Oli.Repo.update_all(
        from(s in Oli.Delivery.Sections.Section, where: s.id == ^section.id),
        set: [root_section_resource_id: root.id]
      )

    %{
      section: %{section | root_section_resource_id: root.id},
      page_a: page_a,
      page_b: page_b,
      empty_page: empty_page,
      container: container,
      objectives: [objective_a, objective_b, direct_only]
    }
  end

  defp sr(section, project, resource, type_id, attrs \\ []) do
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

  defp capture_queries(fun) do
    handler_id = "scope-membership-query-count-#{System.unique_integer([:positive])}"
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
      0 -> Enum.filter(queries, &String.starts_with?(&1, "SELECT"))
    end
  end
end
