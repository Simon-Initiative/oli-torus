defmodule Oli.Accounts.AuthorBrowseTest do
  use Oli.DataCase

  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Accounts
  alias Oli.Accounts.{AuthorBrowseOptions}
  import Ecto.Query, warn: false

  def browse(offset, field, direction, text_search) do
    Accounts.browse_authors(
      %Paging{offset: offset, limit: 3},
      %Sorting{field: field, direction: direction},
      %AuthorBrowseOptions{
        text_search: text_search
      }
    )
  end

  def add(project, author, role_id) do
    Oli.Authoring.Authors.AuthorProject.changeset(%Oli.Authoring.Authors.AuthorProject{}, %{
      project_id: project.id,
      author_id: author.id,
      project_role_id: role_id
    })
    |> Oli.Repo.insert!()
  end

  describe "basic browsing" do
    setup do
      map = Seeder.base_project_with_resource2()
      Seeder.another_project(map.author, map.institution, "test project 2")

      Enum.map(0..9, fn value ->
        author_fixture(%{name: List.to_string([value + 65])})
      end)

      map
    end

    test "basic browsing functionality", %{} do
      # Verify that sorting works:
      results = browse(0, :name, :asc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 13
      assert hd(results).name == "A"

      results = browse(0, :name, :desc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 13
      assert hd(results).name == "J"

      # Verify that sorting by number of collaborators works (and that the
      # aggregation itself is correct)
      results = browse(0, :collaborations_count, :desc, nil)
      assert length(results) == 3
      assert hd(results).total_count == 13
      assert hd(results).name == "First Last"
      assert hd(results).collaborations_count == 2

      # Results should be 3 total, one from this specific setup and two inherited from
      # Seeder.base_project_with_resource2/0
      results = browse(0, :name, :desc, "F")
      assert length(results) == 3
      assert hd(results).total_count == 3
    end
  end
end
