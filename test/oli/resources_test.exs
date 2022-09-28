defmodule Oli.Resources.ResourcesTest do
  use Oli.DataCase

  import Oli.Utils.Seeder.Utils

  alias Oli.Resources
  alias Oli.Utils.Seeder
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}

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

  describe "resources page_titles/2" do
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

    test "should return a map of page titles for the corresponding resolver", %{
      project: project,
      unscored_page1: unscored_page1,
      scored_page2: scored_page2,
      new_unpublished_page: new_unpublished_page,
      section: section
    } do
      assert Resources.page_titles(project.slug, AuthoringResolver) == %{
               unscored_page1.slug => "Unscored page one",
               scored_page2.slug => "Scored page two",
               new_unpublished_page.slug => "A new unpublished page"
             }

      assert Resources.page_titles(section.slug, DeliveryResolver) == %{
               unscored_page1.slug => "Unscored page one",
               scored_page2.slug => "Scored page two"
             }
    end
  end
end
