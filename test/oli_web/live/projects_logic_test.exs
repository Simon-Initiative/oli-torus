defmodule OliWeb.Projects.StateLogicTest do
  use Oli.DataCase
  alias Oli.Authoring.Course
  alias Oli.Accounts
  alias OliWeb.Projects.State

  def merge_changes(changes, state) do
    Map.merge(state, Enum.reduce(changes, %{}, fn {k, v}, m -> Map.put(m, k, v) end))
  end

  describe "projects live state" do
    setup do
      map1 = Seeder.base_project_with_resource2()
      Seeder.another_project(map1.author, map1.institution, "Apple")
      # sleep to ensure Zebra project is created much later
      :timer.sleep(2000)
      Seeder.another_project(map1.author, map1.institution, "Zebra")

      map1
    end

    test "sorting", %{author: author} do
      projects = Course.get_projects_for_author(author)
      author_projects = Accounts.project_authors(Enum.map(projects, fn %{id: id} -> id end))

      state = State.initialize_state(author, projects, author_projects)

      assert length(state.projects) == 3
      assert state.sort_by == "title"
      assert state.sort_order == "asc"
      assert hd(state.projects).title == "Apple"

      state = State.sort_projects(state, "title", "desc") |> merge_changes(state)
      assert state.sort_by == "title"
      assert state.sort_order == "desc"
      assert hd(state.projects).title == "Zebra"

      state = State.sort_projects(state, "created", "desc") |> merge_changes(state)
      assert state.sort_by == "created"
      assert state.sort_order == "desc"
      assert hd(state.projects).title == "Zebra"
    end
  end
end
