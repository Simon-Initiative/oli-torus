defmodule Oli.Delivery.Sections.DataTypeTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Repo

  defp setup_section(_) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)

    Seeder.ensure_published(map.publication.id)

    Seeder.create_section_resources(map)
  end

  describe "data type length" do
    setup [:setup_section]

    @tag isolation: "serializable"
    test "data type length of section resources",
         %{
           o1: o1,
           section: section
         } do
      # read the current section resource record
      sr = Oli.Delivery.Sections.get_section_resource(section.id, o1.resource.id)

      # verfiy that for the title, poster_image, and intro_video fields that we can persist
      # a string of length 1000
      attrs = %{
        title: String.duplicate("a", 1000),
        poster_image: String.duplicate("b", 1000),
        intro_video: String.duplicate("c", 1000)
      }

      {:ok, _} =
        SectionResource.changeset(sr, attrs)
        |> Repo.update()

      sr = Oli.Delivery.Sections.get_section_resource(section.id, o1.resource.id)
      assert sr.title == String.duplicate("a", 1000)
      assert sr.poster_image == String.duplicate("b", 1000)
      assert sr.intro_video == String.duplicate("c", 1000)
    end
  end
end
