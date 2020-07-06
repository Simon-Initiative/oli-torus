defmodule OliWeb.Projects.State do

  alias Oli.Authoring.Course.Project
  alias Oli.Accounts.{SystemRole}

  @default_sort_by "title"
  @default_sort_order "asc"

  @default_state %{
    projects: [],
    authors: %{},
    author: nil,
    sort_order: @default_sort_order,
    sort_by: @default_sort_by,
    changeset: Project.changeset(%Project{
      title: ""
    }),
    is_admin: false,
    title: "Projects"
  }

  def initialize_state(author, projects, author_projects) do

    authors = author_projects
    |> Enum.reduce(%{}, fn [author, project_id], m ->
      case Map.get(m, project_id) do
        nil -> Map.put(m, project_id, [author])
        list -> Map.put(m, project_id, [author | list])
      end
    end)
    # Sort the authors within each project by last name
    |> Enum.reduce(%{}, fn {k, v}, m ->
      Map.put(m, k, Enum.sort(v, fn a1, a2 -> a1.last_name < a2.last_name end))
    end)

    state = @default_state
    |> with_changes([
      projects: projects,
      author: author,
      authors: authors,
      is_admin: SystemRole.role_id().admin == author.system_role_id,
    ])

    with_changes(state, sort_projects(state, @default_sort_by, @default_sort_order))
  end

  def sort_projects(state, sort_by, sort_order) do
    [
      sort_by: sort_by,
      sort_order: sort_order,
      projects: Enum.sort(state.projects, fn p1, p2 ->
        case sort_by do
          "title" -> if sort_order == "asc" do p1.title < p2.title else p2.title < p1.title end
          "created" -> if sort_order == "asc" do p1.inserted_at < p2.inserted_at else p2.inserted_at < p1.inserted_at end
          "author" -> if sort_order == "asc" do p1.inserted_at < p2.inserted_at else p2.inserted_at < p1.inserted_at end
        end
      end)
    ]
  end

  defp with_changes(state, changes) do
    Map.merge(state, Enum.reduce(changes, %{}, fn {k, v}, m -> Map.put(m, k, v) end))
  end

end
