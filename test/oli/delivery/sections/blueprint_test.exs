defmodule Oli.Delivery.Sections.BlueprintTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  import Ecto.Query, warn: false

  describe "section updates" do
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
          context_id: "1",
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
          context_id: "1",
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
end
