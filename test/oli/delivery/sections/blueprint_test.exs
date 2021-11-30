defmodule Oli.Delivery.Sections.BlueprintTest do
  use Oli.DataCase

  import Oli.Factory
  import Ecto.Query, warn: false

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing

  describe "basic blueprint operations" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "is_author_of_blueprint?/2 correctly identifies authors", %{
      project: project,
      institution: institution,
      author: author
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

      # Create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      {:ok, duplicate} = Blueprint.duplicate(section)

      assert duplicate.type == :blueprint
      refute duplicate.id == section.id
      refute duplicate.slug == section.slug

      assert Blueprint.is_author_of_blueprint?(duplicate.slug, author.id)
      refute Blueprint.is_author_of_blueprint?(section.slug, author.id)
    end

    test "duplicate/1 deep copies a course section, turning it into a blueprint", %{
      project: project,
      institution: institution
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

      # Create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      {:ok, %{id: id} = duplicate} = Blueprint.duplicate(section)

      assert duplicate.type == :blueprint
      refute duplicate.id == section.id
      refute duplicate.slug == section.slug
      refute duplicate.root_section_resource_id == section.root_section_resource_id

      duped =
        get_resources(id)
        |> Enum.map(fn s -> s.id end)
        |> MapSet.new()

      original =
        get_resources(section.id)
        |> Enum.map(fn s -> s.id end)
        |> MapSet.new()

      assert MapSet.size(duped) == MapSet.size(original)
      assert MapSet.disjoint?(duped, original)

      duped =
        get_pub_mappings(id)
        |> MapSet.new()

      original =
        get_pub_mappings(section.id)
        |> MapSet.new()

      assert MapSet.size(duped) == MapSet.size(original)
    end

    def get_resources(id) do
      query =
        from(
          s in Oli.Delivery.Sections.SectionResource,
          where: s.section_id == ^id,
          select: s
        )

      Repo.all(query)
    end

    def get_pub_mappings(id) do
      query =
        from(
          s in Oli.Delivery.Sections.SectionsProjectsPublications,
          where: s.section_id == ^id,
          select: s
        )

      Repo.all(query)
    end
  end

  describe "blueprint availability based on visibility" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "is_author_of_blueprint?/2 correctly identifies authors", %{
      project: project,
      institution: institution,
      author: author,
      author2: author2
    } do
      another = Seeder.another_project(author2, institution, "second one")

      {:ok, _} =
        Sections.create_section(%{
          type: :blueprint,
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: another.project.id
        })

      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

      # Create a blueprint using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          type: :blueprint,
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      {:ok, _} = Blueprint.duplicate(section)

      # At this point, the author should only have access to two products (the
      # ones build from the project this author created)
      available = Blueprint.available_products(author, institution)
      assert length(available) == 2

      # We then change the other project to be global visibility, but project
      # does not yet have a publication, so the product created from it is not
      # visible.
      Course.update_project(another.project, %{visibility: :global})
      available = Blueprint.available_products(author, institution)
      assert length(available) == 2

      # After publishing the project, the product is now visible
      {:ok, _} = Publishing.publish_project(another.project, "some changes")
      available = Blueprint.available_products(author, institution)
      assert length(available) == 3
    end

    test "list_products_not_in_community/1 returns the products that are not associated to the community" do
      [first_section | _tail] = insert_list(2, :section)
      community_visibility = insert(:community_visibility, %{section: first_section})

      assert 2 = length(Blueprint.list())

      assert 1 =
               length(Blueprint.list_products_not_in_community(community_visibility.community_id))
    end
  end
end
