defmodule Oli.MajorUpdatesTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Publishing
  alias Oli.Delivery.Hierarchy
  alias Oli.Seeder
  alias Oli.Repo

  describe "remix major updates" do
    setup do
      # Create source project using existing seeder helper
      source_map = Seeder.base_project_with_resource2()

      # Create destination project using existing seeder helper
      dest_map = Seeder.base_project_with_resource2()

      # Publish the destination project to get an initial publication for the section
      {:ok, dest_initial_pub} =
        Publishing.publish_project(dest_map.project, "initial destination", dest_map.author.id)

      # Create a course section using the destination project's initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "Test Course Section",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: dest_map.institution.id,
          base_project_id: dest_map.project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(dest_initial_pub)

      {:ok,
       %{
         source_map: source_map,
         dest_map: dest_map,
         dest_initial_pub: dest_initial_pub,
         section: section
       }}
    end

    @tag capture_log: true
    test "major update incorrectly removes remixed container from another project", %{
      source_map: source_map,
      dest_map: dest_map,
      section: section
    } do
      # Verify the initial curriculum structure - should have 2 pages in the root container
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)
      assert hierarchy.children |> Enum.count() == 2
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == dest_map.page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == dest_map.page2.id

      # TODO: Add remix functionality here - this is where we will remix content from source_project into the section
      # source_map has: project, publication, container, page1, page2, author, institution etc.
      # dest_map has: project, publication, container, page1, page2, author, institution etc.

      # REMIX: Add the entire source container into the section
      # Step 1: Get current hierarchy
      current_hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      # Step 2: Prepare selection (we want to remix the source container)
      source_container_resource_id = source_map.container.resource.id
      source_publication_id = source_map.publication.id
      selection = [{source_publication_id, source_container_resource_id}]

      # Step 3: Get published resources for the source publication
      published_resources_by_resource_id_by_pub =
        Publishing.get_published_resources_for_publications([source_publication_id])

      # Step 4: Add the source container to the current section's hierarchy
      updated_hierarchy =
        Hierarchy.add_materials_to_hierarchy(
          current_hierarchy,
          # add to root level
          current_hierarchy,
          selection,
          published_resources_by_resource_id_by_pub
        )
        |> Hierarchy.finalize()

      # Step 5: Get current pinned publications and add the source publication
      current_pinned_publications = Sections.get_pinned_project_publications(section.id)

      updated_pinned_publications =
        Map.put(current_pinned_publications, source_map.project.id, source_map.publication)

      # Step 6: Apply the remix by rebuilding the section curriculum
      Sections.rebuild_section_curriculum(section, updated_hierarchy, updated_pinned_publications)

      # Verify the remix worked - should now have dest pages + source container with source pages
      updated_hierarchy = DeliveryResolver.full_hierarchy(section.slug)
      # 2 dest pages + 1 source container
      assert updated_hierarchy.children |> Enum.count() == 3

      # Find the remixed container
      source_container_in_section =
        Enum.find(updated_hierarchy.children, fn child ->
          child.resource_id == source_container_resource_id
        end)

      assert source_container_in_section != nil
      # source container has 2 pages
      assert source_container_in_section.children |> Enum.count() == 2

      # MAJOR UPDATE: Now make major changes to the destination project
      # This will trigger the bug where the remixed source container gets incorrectly removed

      # Get the working publication for the destination project to make changes
      dest_working_pub = Publishing.project_working_publication(dest_map.project.slug)

      # Make major structural changes - add a new container with pages to the destination project
      %{resource: new_dest_container_resource, revision: new_dest_container_revision} =
        Seeder.create_container(
          "New Dest Container",
          dest_working_pub,
          dest_map.project,
          dest_map.author
        )

      %{resource: new_dest_page_resource, revision: _new_dest_page_revision} =
        Seeder.create_page("New Dest Page", dest_working_pub, dest_map.project, dest_map.author)

      # Attach the new page to the new container
      _new_dest_container_revision =
        Seeder.attach_pages_to(
          [new_dest_page_resource],
          new_dest_container_resource,
          new_dest_container_revision,
          dest_working_pub
        )

      # Attach the new container to the root container of dest project
      dest_container = dest_map.container

      _updated_dest_container_revision =
        Seeder.attach_pages_to(
          [new_dest_container_resource],
          dest_container.resource,
          dest_container.revision,
          dest_working_pub
        )

      # Publish the major changes (this creates a MAJOR publication)
      {:ok, major_publication} =
        Publishing.publish_project(
          dest_map.project,
          "major structural changes",
          dest_map.author.id
        )

      # APPLY THE MAJOR UPDATE: This is where the bug should manifest
      # The apply_publication_update should preserve the remixed source container, but the bug causes it to be removed
      Oli.Delivery.Sections.Updates.apply_publication_update(section, major_publication.id)

      # VERIFY THE BUG: Check if the remixed container was incorrectly removed
      final_hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      _final_resource_ids = Enum.map(final_hierarchy.children, & &1.resource_id)

      # Check if section resources still exist
      final_section_resources = Sections.get_section_resources(section.id)

      _source_srs =
        Enum.filter(final_section_resources, fn sr ->
          sr.resource_id == source_container_resource_id
        end)

      # The section should still have the remixed source container, but the bug removes it
      remaining_source_container =
        Enum.find(final_hierarchy.children, fn child ->
          child.resource_id == source_container_resource_id
        end)

      # This assertion FAILS due to the bug - when a major publication update is applied to a project,
      # it incorrectly removes remixed containers from OTHER projects that were added to the section
      assert remaining_source_container != nil,
             "BUG: Major publication update incorrectly removed remixed container from source project"
    end

    @tag capture_log: true
    test "remixed project update then base project major update causes crash without fix", %{
      source_map: source_map,
      dest_map: dest_map,
      section: section
    } do
      # Bug: Remix external project → external adds resource (children: nil) →
      # base project major update → crash on nil.children in update_container_children.
      # Fix: Add guard `and not is_nil(new_published_resource)` in Oli.Delivery.Sections.Updates

      # Publish source project (seeder returns unpublished working publication)
      {:ok, source_initial_pub} =
        Publishing.publish_project(source_map.project, "initial source", source_map.author.id)

      # STEP 1: Remix source container into section
      current_hierarchy = DeliveryResolver.full_hierarchy(section.slug)
      source_container_resource_id = source_map.container.resource.id
      selection = [{source_initial_pub.id, source_container_resource_id}]

      published_resources_by_resource_id_by_pub =
        Publishing.get_published_resources_for_publications([source_initial_pub.id])

      updated_hierarchy =
        Hierarchy.add_materials_to_hierarchy(
          current_hierarchy,
          current_hierarchy,
          selection,
          published_resources_by_resource_id_by_pub
        )
        |> Hierarchy.finalize()

      updated_pinned_publications =
        Sections.get_pinned_project_publications(section.id)
        |> Map.put(source_map.project.id, source_initial_pub)

      Sections.rebuild_section_curriculum(section, updated_hierarchy, updated_pinned_publications)
      assert DeliveryResolver.full_hierarchy(section.slug).children |> Enum.count() == 3

      # STEP 2: Source project adds NEW ACTIVITY (using activity, not page - pages get culled)
      source_working_pub = Publishing.project_working_publication(source_map.project.slug)

      %{resource: new_source_activity_resource, revision: _} =
        Seeder.create_activity(
          %{title: "New Source Activity", content: %{}},
          source_working_pub,
          source_map.project,
          source_map.author
        )

      {:ok, source_update_pub} =
        Publishing.publish_project(source_map.project, "added activity", source_map.author.id)

      # STEP 3: Apply source update → new activity gets children: nil (the bug trigger)
      Oli.Delivery.Sections.Updates.apply_publication_update(section, source_update_pub.id)

      new_activity_sr =
        Repo.get_by(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: new_source_activity_resource.id
        )

      assert new_activity_sr != nil
      assert new_activity_sr.children == nil, "children must be nil to trigger the bug"

      # STEP 4: Base project (dest) publishes MAJOR update
      dest_working_pub = Publishing.project_working_publication(dest_map.project.slug)

      %{resource: new_dest_container_resource, revision: new_dest_container_revision} =
        Seeder.create_container(
          "New Dest Container",
          dest_working_pub,
          dest_map.project,
          dest_map.author
        )

      %{resource: new_dest_page_resource, revision: _} =
        Seeder.create_page("New Dest Page", dest_working_pub, dest_map.project, dest_map.author)

      _new_dest_container_revision =
        Seeder.attach_pages_to(
          [new_dest_page_resource],
          new_dest_container_resource,
          new_dest_container_revision,
          dest_working_pub
        )

      dest_container = dest_map.container

      _updated_dest_container_revision =
        Seeder.attach_pages_to(
          [new_dest_container_resource],
          dest_container.resource,
          dest_container.revision,
          dest_working_pub
        )

      {:ok, dest_major_pub} =
        Publishing.publish_project(dest_map.project, "major update", dest_map.author.id)

      # STEP 5: Apply base project major update → crashes without fix, succeeds with fix
      Oli.Delivery.Sections.Updates.apply_publication_update(section, dest_major_pub.id)

      # Verify remixed content is preserved
      final_hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      source_container_in_section =
        Enum.find(final_hierarchy.children, &(&1.resource_id == source_container_resource_id))

      assert source_container_in_section != nil, "Remixed container should be preserved"
    end
  end
end
