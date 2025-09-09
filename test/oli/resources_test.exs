defmodule Oli.Resources.ResourcesTest do
  use Oli.DataCase

  import Oli.Utils.Seeder.Utils
  import Oli.Factory

  alias Oli.Resources
  alias Oli.Utils.Seeder
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Rendering.Content.ResourceSummary

  describe "resources" do
    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "list_resources/0 returns all resources", _ do
      assert length(Resources.list_resources()) == 3
    end

    test "get_resource!/1 returns the resource with given id", %{
      container: %{resource: container_resource}
    } do
      assert Resources.get_resource!(container_resource.id) == container_resource
    end
  end

  describe "get_page_resource_ids_with_lti_activities/1" do
    setup :create_elixir_project

    test "returns a list of resource ids that have lti activities", %{
      section: section,
      page1: page1_revision,
      page2: page2_revision,
      page3: _page3_revision
    } do
      # There are 3 pages, but only 2 have LTI activities (page 3 has no LTI activities).
      assert length(
               MapSet.to_list(Resources.get_page_resource_ids_with_lti_activities(section.id))
             ) == 2

      assert MapSet.to_list(Resources.get_page_resource_ids_with_lti_activities(section.id)) == [
               page1_revision.resource_id,
               page2_revision.resource_id
             ]
    end
  end

  describe "resources title/2" do
    setup do
      %{}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :project,
        publication_tag: :pub,
        curriculum_revision_tag: :curriculum,
        unscored_page1_tag: :unscored_page1,
        unscored_page1_activity_tag: :unscored_page1_activity,
        scored_page2_tag: :scored_page2,
        scored_page2_activity_tag: :scored_page2_activity
      )
      |> Seeder.Project.ensure_published(ref(:pub))
      |> Seeder.Section.create_section(
        ref(:project),
        ref(:pub),
        nil,
        %{},
        section_tag: :section
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:project),
        ref(:curriculum),
        %{
          title: "A new unpublished page",
          content: %{"model" => []},
          graded: false
        },
        revision_tag: :new_unpublished_page
      )
    end

    test "should return the revision title for a given resource_id, project or section slug and resolver",
         %{
           project: project,
           unscored_page1: unscored_page1,
           scored_page2: scored_page2,
           new_unpublished_page: new_unpublished_page,
           section: section
         } do
      assert Resources.resource_summary(
               unscored_page1.resource_id,
               project.slug,
               AuthoringResolver
             ) ==
               %ResourceSummary{title: "Unscored page one", slug: unscored_page1.slug}

      assert Resources.resource_summary(scored_page2.resource_id, project.slug, AuthoringResolver) ==
               %ResourceSummary{title: "Scored page two", slug: scored_page2.slug}

      assert Resources.resource_summary(
               new_unpublished_page.resource_id,
               project.slug,
               AuthoringResolver
             ) ==
               %ResourceSummary{title: "A new unpublished page", slug: new_unpublished_page.slug}

      assert Resources.resource_summary(scored_page2.resource_id, section.slug, DeliveryResolver) ==
               %ResourceSummary{title: "Scored page two", slug: scored_page2.slug}
    end
  end

  defp create_elixir_project(_context) do
    author = insert(:author)
    project = insert(:project)

    # Create two LTI activity registrations (tools) and one multiple choice activity registration

    lti_tool1 = insert(:activity_registration, title: "Tool One")
    lti_tool2 = insert(:activity_registration, title: "Tool Two")
    mcq_activity_registration = insert(:activity_registration, title: "Multiple Choice")

    platform1 =
      insert(:platform_instance, %{
        name: "Platform One",
        description: "First platform"
      })

    platform2 =
      insert(:platform_instance, %{
        name: "Platform Two",
        description: "Second platform"
      })

    _deployment1 =
      insert(:lti_external_tool_activity_deployment,
        activity_registration: lti_tool1,
        platform_instance: platform1
      )

    _deployment2 =
      insert(:lti_external_tool_activity_deployment,
        activity_registration: lti_tool2,
        platform_instance: platform2
      )

    # Create tool revisions
    tool1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
        activity_type_id: lti_tool1.id,
        title: "Tool One Activity Revision"
      })

    tool2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
        activity_type_id: lti_tool2.id,
        title: "Tool Two Activity Revision"
      })

    mcq_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
        activity_type_id: mcq_activity_registration.id,
        title: "MCQ Revision"
      })

    # Create page revisions that reference the tool revisions
    page1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Page One",
        activity_refs: [
          tool1_revision.resource_id,
          tool2_revision.resource_id
        ]
      })

    page2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Page Two",
        activity_refs: [tool2_revision.resource_id]
      })

    page3_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Page Three",
        activity_refs: [mcq_revision.resource_id]
      })

    # Create a container revision (root)
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        title: "Root Container",
        children: [page1_revision.resource_id, page2_revision.resource_id]
      })

    all_revisions = [
      tool1_revision,
      tool2_revision,
      page1_revision,
      page2_revision,
      page3_revision,
      container_revision
    ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, project: project, root_resource_id: container_revision.resource_id)

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # Create section
    section =
      insert(:section,
        base_project: project,
        analytics_version: :v2,
        type: :enrollable
      )

    {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)
    {:ok, _} = Oli.Delivery.Sections.rebuild_contained_pages(section)
    {:ok, _} = Oli.Delivery.Sections.rebuild_contained_objectives(section)
    Oli.Delivery.Sections.SectionResourceMigration.migrate(section.id)

    %{
      section: section,
      tool1: lti_tool1,
      tool2: lti_tool2,
      page1: page1_revision,
      page2: page2_revision,
      page3: page3_revision
    }
  end
end
