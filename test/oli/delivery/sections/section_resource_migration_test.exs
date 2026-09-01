defmodule Oli.Delivery.Sections.SectionResourceMigrationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.Depot
  alias Oli.Delivery.DistributedDepotCoordinator

  describe "requires_migration?/1" do
    test "returns true when section has section resources not yet migrated" do
      section = insert(:section)

      insert(:section_resource, section: section, graded: nil)

      assert SectionResourceMigration.requires_migration?(section.id)
    end

    test "returns false when section has all section resources migrated" do
      section = insert(:section)

      insert(:section_resource, section: section, graded: true)
      insert(:section_resource, section: section, graded: false)

      refute SectionResourceMigration.requires_migration?(section.id)
    end

    test "returns true when section has mix of resources migrated and not yet migrated" do
      section = insert(:section)

      insert(:section_resource, section: section, graded: true)
      insert(:section_resource, section: section, graded: nil)

      assert SectionResourceMigration.requires_migration?(section.id)
    end
  end

  describe "migrate/1" do
    test "migrates all section resources for a given section" do
      # Create test data
      section = insert(:section)
      project = insert(:project)
      publication = insert(:publication, project: project)

      # Create sections_projects_publications relationship
      insert(:section_project_publication,
        section: section,
        project: project,
        publication: publication
      )

      # Create resources and revisions
      resource1 = insert(:resource)
      resource2 = insert(:resource)

      revision1 =
        insert(:revision,
          resource: resource1,
          title: "Test Resource 1",
          graded: true,
          ai_enabled: false,
          purpose: :application
        )

      revision2 =
        insert(:revision,
          resource: resource2,
          title: "Test Resource 2",
          graded: false,
          ai_enabled: true,
          purpose: :foundation
        )

      # Create published resources
      insert(:published_resource,
        resource: resource1,
        publication: publication,
        revision: revision1
      )

      insert(:published_resource,
        resource: resource2,
        publication: publication,
        revision: revision2
      )

      # Create section resources with old data
      section_resource1 =
        insert(:section_resource,
          section: section,
          resource_id: resource1.id,
          title: "Old Title 1",
          graded: nil,
          purpose: nil
        )

      section_resource2 =
        insert(:section_resource,
          section: section,
          resource_id: resource2.id,
          title: "Old Title 2",
          graded: nil,
          purpose: nil
        )

      # Perform migration
      assert {:ok, 2} = SectionResourceMigration.migrate(section.id)

      # Verify the section resources were updated
      updated_sr1 = Repo.get(SectionResource, section_resource1.id)
      updated_sr2 = Repo.get(SectionResource, section_resource2.id)

      assert updated_sr1.title == "Test Resource 1"
      assert updated_sr1.graded == true
      assert updated_sr1.ai_enabled == false
      assert updated_sr1.purpose == :application
      assert updated_sr1.project_slug == project.slug
      assert updated_sr1.revision_slug == revision1.slug
      assert updated_sr1.revision_id == revision1.id

      assert updated_sr2.title == "Test Resource 2"
      assert updated_sr2.graded == false
      assert updated_sr2.ai_enabled == true
      assert updated_sr2.purpose == :foundation
      assert updated_sr2.project_slug == project.slug
      assert updated_sr2.revision_slug == revision2.slug
      assert updated_sr2.revision_id == revision2.id
    end

    test "handles section with no section resources" do
      section = insert(:section)

      assert {:ok, 0} = SectionResourceMigration.migrate(section.id)
    end
  end

  describe "migrate_specific_resources/2" do
    test "migrates only specified section resources" do
      # Create test data
      section = insert(:section)
      project = insert(:project)
      publication = insert(:publication, project: project)

      insert(:section_project_publication,
        section: section,
        project: project,
        publication: publication
      )

      # Create resources and revisions
      resource1 = insert(:resource)
      resource2 = insert(:resource)
      resource3 = insert(:resource)

      revision1 =
        insert(:revision,
          resource: resource1,
          title: "Test Resource 1",
          graded: true,
          ai_enabled: false
        )

      revision2 =
        insert(:revision,
          resource: resource2,
          title: "Test Resource 2",
          graded: false,
          ai_enabled: true
        )

      revision3 =
        insert(:revision,
          resource: resource3,
          title: "Test Resource 3",
          graded: true,
          ai_enabled: false
        )

      # Create published resources
      insert(:published_resource,
        resource: resource1,
        publication: publication,
        revision: revision1
      )

      insert(:published_resource,
        resource: resource2,
        publication: publication,
        revision: revision2
      )

      insert(:published_resource,
        resource: resource3,
        publication: publication,
        revision: revision3
      )

      # Create section resources
      section_resource1 =
        insert(:section_resource,
          section: section,
          resource_id: resource1.id,
          title: "Old Title 1",
          graded: nil
        )

      section_resource2 =
        insert(:section_resource,
          section: section,
          resource_id: resource2.id,
          title: "Old Title 2",
          graded: nil
        )

      section_resource3 =
        insert(:section_resource,
          section: section,
          resource_id: resource3.id,
          title: "Old Title 3",
          graded: nil
        )

      # Migrate only resources 1 and 2
      resource_ids_to_migrate = [resource1.id, resource2.id]

      assert {:ok, 2} =
               SectionResourceMigration.migrate_specific_resources(
                 section.id,
                 resource_ids_to_migrate
               )

      # Verify only the specified resources were updated
      updated_sr1 = Repo.get(SectionResource, section_resource1.id)
      updated_sr2 = Repo.get(SectionResource, section_resource2.id)
      updated_sr3 = Repo.get(SectionResource, section_resource3.id)

      assert updated_sr1.title == "Test Resource 1"
      assert updated_sr1.graded
      refute updated_sr1.ai_enabled
      assert updated_sr2.title == "Test Resource 2"
      refute updated_sr2.graded
      assert updated_sr2.ai_enabled

      # This one should remain unchanged
      assert updated_sr3.title == "Old Title 3"
      refute updated_sr3.graded
      assert is_nil(updated_sr3.ai_enabled)
    end

    test "returns {:ok, 0} for empty resource_ids list" do
      section = insert(:section)

      assert {:ok, 0} = SectionResourceMigration.migrate_specific_resources(section.id, [])
    end

    test "handles non-existent resource IDs gracefully" do
      section = insert(:section)

      assert {:ok, 0} =
               SectionResourceMigration.migrate_specific_resources(section.id, [99999, 88888])
    end
  end

  describe "migration data integrity" do
    test "preserves all required fields during migration" do
      section = insert(:section)
      project = insert(:project)
      publication = insert(:publication, project: project)

      insert(:section_project_publication,
        section: section,
        project: project,
        publication: publication
      )

      resource = insert(:resource)

      revision =
        insert(:revision,
          resource: resource,
          title: "Complete Test Resource",
          graded: true,
          ai_enabled: false,
          purpose: :foundation,
          duration_minutes: 30,
          intro_content: %{"some" => "Introduction content"},
          intro_video: "video_url",
          poster_image: "image_url",
          activity_type_id: 1
        )

      insert(:published_resource,
        resource: resource,
        publication: publication,
        revision: revision
      )

      section_resource =
        insert(:section_resource,
          section: section,
          resource_id: resource.id,
          title: "Old Title",
          graded: nil,
          purpose: nil,
          duration_minutes: nil,
          intro_content: nil,
          intro_video: nil,
          poster_image: nil,
          objectives: nil,
          relates_to: nil,
          activity_type_id: nil
        )

      # Perform migration
      assert {:ok, 1} = SectionResourceMigration.migrate(section.id)

      # Verify all fields were properly migrated
      updated_sr = Repo.get(SectionResource, section_resource.id)

      assert updated_sr.title == "Complete Test Resource"
      assert updated_sr.graded == true
      assert updated_sr.ai_enabled == false
      assert updated_sr.purpose == :foundation
      assert updated_sr.duration_minutes == 30
      assert updated_sr.intro_content == %{"some" => "Introduction content"}
      assert updated_sr.intro_video == "video_url"
      assert updated_sr.poster_image == "image_url"
      assert updated_sr.activity_type_id == 1
      assert updated_sr.project_slug == project.slug
      assert updated_sr.revision_slug == revision.slug
      assert updated_sr.revision_id == revision.id
      assert updated_sr.resource_type_id == revision.resource_type_id
    end
  end

  describe "versioned JIT migration" do
    test "migrates version zero once and treats a current version as a no-op" do
      %{section: section, page: page, activity: activity} = pinned_projection_fixture()

      assert section.section_resource_migration_version == 0
      assert {:ok, :migrated} = SectionResourceMigration.ensure_current(section.id)

      migrated_section = Repo.reload(section)
      migrated_page = Repo.reload(page)

      assert migrated_section.section_resource_migration_version ==
               SectionResourceMigration.current_version()

      assert migrated_page.related_activities == [activity.resource_id]
      assert {:ok, :current} = SectionResourceMigration.ensure_current(section.id)
    end

    test "rejects a future marker without modifying it" do
      section = insert(:section)
      future = SectionResourceMigration.current_version() + 1

      Repo.update_all(
        from(s in Oli.Delivery.Sections.Section, where: s.id == ^section.id),
        set: [section_resource_migration_version: future]
      )

      assert {:error, {:unsupported_future_version, ^future}} =
               SectionResourceMigration.ensure_current(section.id)

      assert Repo.reload(section).section_resource_migration_version == future
    end

    test "rolls back the marker on failure and succeeds on retry" do
      %{section: section} = pinned_projection_fixture()
      previous = Application.get_env(:oli, :related_activities_projection)

      Application.put_env(
        :oli,
        :related_activities_projection,
        Oli.Test.Sections.FailingRelatedActivitiesProjection
      )

      on_exit(fn -> restore_projection_module(previous) end)

      assert {:error, :forced_projection_failure} =
               SectionResourceMigration.ensure_current(section.id)

      assert Repo.reload(section).section_resource_migration_version == 0

      Application.delete_env(:oli, :related_activities_projection)
      assert {:ok, :migrated} = SectionResourceMigration.ensure_current(section.id)
    end

    test "rolls back projection writes together with the marker" do
      %{section: section, page: page} = pinned_projection_fixture()
      previous = Application.get_env(:oli, :related_activities_projection)

      Application.put_env(
        :oli,
        :related_activities_projection,
        Oli.Test.Sections.PartiallyFailingRelatedActivitiesProjection
      )

      on_exit(fn -> restore_projection_module(previous) end)

      assert {:error, :forced_projection_failure_after_write} =
               SectionResourceMigration.ensure_current(section.id)

      assert Repo.reload(page).related_activities == []
      assert Repo.reload(section).section_resource_migration_version == 0

      Application.delete_env(:oli, :related_activities_projection)
      assert {:ok, :migrated} = SectionResourceMigration.ensure_current(section.id)
    end

    test "concurrent first access has one effective migration" do
      %{section: section} = pinned_projection_fixture()

      results =
        1..2
        |> Enum.map(fn _ ->
          Task.async(fn -> SectionResourceMigration.ensure_current(section.id) end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.sort(results) == Enum.sort([{:ok, :current}, {:ok, :migrated}])
    end

    test "depot initialization propagates migration failure without creating a table" do
      %{section: section} = pinned_projection_fixture()
      previous = Application.get_env(:oli, :related_activities_projection)

      Application.put_env(
        :oli,
        :related_activities_projection,
        Oli.Test.Sections.FailingRelatedActivitiesProjection
      )

      on_exit(fn -> restore_projection_module(previous) end)

      assert {:error, :forced_projection_failure} =
               SectionResourceDepot.process_table_creation(section.id)

      refute Depot.table_exists?(SectionResourceDepot.depot_desc(), section.id)
    end

    test "missing sections return a bounded initialization error" do
      missing_section_id = -1

      assert {:error, {:section_not_found, ^missing_section_id}} =
               SectionResourceDepot.process_table_creation(missing_section_id)

      refute Depot.table_exists?(SectionResourceDepot.depot_desc(), missing_section_id)
    end

    test "distributed initialization propagates errors and invalidation is synchronous locally" do
      missing_section_id = -1

      assert {:error, {:section_not_found, ^missing_section_id}} =
               DistributedDepotCoordinator.init_if_necessary(
                 SectionResourceDepot.depot_desc(),
                 missing_section_id,
                 SectionResourceDepot
               )

      %{section: section} = pinned_projection_fixture()

      assert {:ok, :created} =
               DistributedDepotCoordinator.init_if_necessary(
                 SectionResourceDepot.depot_desc(),
                 section.id,
                 SectionResourceDepot
               )

      assert Depot.table_exists?(SectionResourceDepot.depot_desc(), section.id)

      assert :ok =
               DistributedDepotCoordinator.clear_synchronously(
                 SectionResourceDepot.depot_desc(),
                 section.id
               )

      refute Depot.table_exists?(SectionResourceDepot.depot_desc(), section.id)
    end
  end

  defp pinned_projection_fixture do
    project = insert(:project)
    publication = insert(:publication, project: project)
    section = insert(:section, base_project: project)
    activity = insert(:revision, resource_type_id: Oli.Resources.ResourceType.id_for_activity())

    page =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        activity_refs: [activity.resource_id]
      )

    Enum.each([activity, page], fn revision ->
      insert(:published_resource,
        publication: publication,
        resource: revision.resource,
        revision: revision
      )
    end)

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
    )

    insert(:section_resource,
      section: section,
      project: project,
      resource_id: activity.resource_id,
      revision_id: activity.id
    )

    page_section_resource =
      insert(:section_resource,
        section: section,
        project: project,
        resource_id: page.resource_id,
        revision_id: page.id,
        resource_type_id: Oli.Resources.ResourceType.id_for_page()
      )

    %{section: section, page: page_section_resource, activity: activity}
  end

  defp restore_projection_module(nil),
    do: Application.delete_env(:oli, :related_activities_projection)

  defp restore_projection_module(module),
    do: Application.put_env(:oli, :related_activities_projection, module)
end
