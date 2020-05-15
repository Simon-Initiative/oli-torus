defmodule Oli.GradingTest do
  use Oli.DataCase

  alias Oli.Repo
  alias Oli.Grading
  alias Oli.Delivery.Attempts.ResourceAccess
  alias Oli.Delivery.Sections

  describe "grading" do
    defp set_resources_as_graded(%{revision1: revision1, revision2: revision2} = map) do
      {:ok, revision1} = Oli.Resources.update_revision(revision1, %{graded: true})
      {:ok, revision2} = Oli.Resources.update_revision(revision2, %{graded: true})
      map = put_in(map.revision1, revision1)
      map = put_in(map.revision2, revision2)

      map
    end

    defp create_users(%{section: section} = map) do
      map = Oli.Seeder.add_user(map, %{user_id: "user1"}, :user1)
      map = Oli.Seeder.add_user(map, %{user_id: "user2"}, :user2)
      map = Oli.Seeder.add_user(map, %{user_id: "user3"}, :user3)

      # enroll users
      Sections.enroll(map.user1.id, section.id, 2)
      Sections.enroll(map.user2.id, section.id, 2)
      Sections.enroll(map.user3.id, section.id, 2)

      map
    end

    defp create_resource_accesses(%{revision1: revision1, revision2: revision2, section: section} = map) do
      scores = %{
        revision1: [12, 20, 19],
        revision2: [0, 3, 5],
      }
      users = [map.user1, map.user2, map.user2]

      # create accesses for resource 1
      users
      |> Enum.with_index
      |> Enum.each(fn {user, i} ->
        IO.inspect %ResourceAccess{}
        |> ResourceAccess.changeset(%{
          access_count: 1,
          score: Enum.at(scores.revision1, i),
          out_of: 20,
          user_id: user.id,
          section_id: section.id,
          resource_id: revision1.resource_id,
        })
        |> Repo.insert()
      end)

      # create accesses for resource 2
      users
      |> Enum.with_index
      |> Enum.each(fn {user, i} ->
        IO.inspect %ResourceAccess{}
        |> ResourceAccess.changeset(%{
          access_count: 1,
          score: Enum.at(scores.revision2, i),
          out_of: 5,
          user_id: user.id,
          section_id: section.id,
          resource_id: revision2.resource_id,
        })
        |> Repo.insert()
      end)

      IO.inspect Repo.all(ResourceAccess), label: "all ResourceAccess"

      Map.put(map, :scores, scores)
    end

    setup do
      Oli.Seeder.base_project_with_resource2()
      |> set_resources_as_graded
      |> Oli.Seeder.create_section
      |> Oli.Seeder.add_lti_consumer(%{}, :lti_consumer)
      |> create_users
      |> create_resource_accesses
    end

    test "returns valid gradebook for section", %{section: section} do
      {gradebook, columns} = Grading.generate_gradebook_for_section(section)

      IO.inspect {gradebook, columns}
    end
  end

end
