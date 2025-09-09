defmodule Oli.Delivery.Sections.SectionResourceMigrationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.Delivery.Sections.SectionResource

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
          purpose: :application
        )

      revision2 =
        insert(:revision,
          resource: resource2,
          title: "Test Resource 2",
          graded: false,
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
      assert updated_sr1.purpose == :application
      assert updated_sr1.project_slug == project.slug
      assert updated_sr1.revision_slug == revision1.slug
      assert updated_sr1.revision_id == revision1.id

      assert updated_sr2.title == "Test Resource 2"
      assert updated_sr2.graded == false
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
          graded: true
        )

      revision2 =
        insert(:revision,
          resource: resource2,
          title: "Test Resource 2",
          graded: false
        )

      revision3 =
        insert(:revision,
          resource: resource3,
          title: "Test Resource 3",
          graded: true
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
      assert updated_sr2.title == "Test Resource 2"
      refute updated_sr2.graded

      # This one should remain unchanged
      assert updated_sr3.title == "Old Title 3"
      refute updated_sr3.graded
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
end
