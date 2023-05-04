defmodule Oli.Resources.ResourcesTest do
  use Oli.DataCase

  import Oli.Utils.Seeder.Utils

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
end
