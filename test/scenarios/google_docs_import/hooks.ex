defmodule Oli.Scenarios.GoogleDocsImport.Hooks do
  @moduledoc false

  import Ecto.Query

  alias Oli.Activities
  alias Oli.Authoring.Course
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Scenarios.DirectiveTypes.ExecutionState

  @default_expected_page_title "Lists"
  @default_expected_text [
    "Google Docs Import Kitchen Sink",
    "Continuous verification",
    "Preserve this content"
  ]
  @expected_activity_slugs MapSet.new([
                             "oli_multiple_choice",
                             "oli_check_all_that_apply",
                             "oli_short_answer",
                             "oli_multi_input"
                           ])

  def assert_imported_project(%ExecutionState{} = state) do
    params = Map.get(state, :params, %{})
    project_slug = param!(params, "project_slug")
    expected_page_title = param(params, "expected_page_title", @default_expected_page_title)
    expected_text = expected_text(params)

    project =
      project_slug
      |> Course.get_project_by_slug()
      |> case do
        nil -> raise "Expected project with slug #{inspect(project_slug)}"
        project -> project
      end

    revision = find_revision!(project.slug, expected_page_title, expected_text)
    model = revision.content["model"] |> List.wrap()
    all_nodes = collect_nodes(model)
    all_text = collect_text(model)

    Enum.each(expected_text, fn text ->
      unless String.contains?(all_text, text) do
        raise "Expected imported page #{inspect(expected_page_title)} to contain #{inspect(text)}"
      end
    end)

    assert_node_type!(all_nodes, "youtube")
    assert_node_type!(all_nodes, "img")
    assert_node_type!(all_nodes, "table")
    assert_activity_types!(all_nodes)

    state
  end

  defp expected_text(params) do
    case param(params, "expected_text", nil) do
      nil ->
        @default_expected_text

      text when is_binary(text) ->
        text
        |> String.split("|")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp find_revision!(project_slug, expected_page_title, expected_text) do
    project_slug
    |> all_working_revisions()
    |> Enum.find(fn revision ->
      revision.title == expected_page_title and
        Enum.all?(expected_text, fn text ->
          revision.content
          |> Map.get("model")
          |> List.wrap()
          |> collect_text()
          |> String.contains?(text)
        end)
    end)
    |> case do
      nil ->
        raise "Expected imported Google Docs page #{inspect(expected_page_title)} in project #{inspect(project_slug)}"

      revision ->
        revision
    end
  end

  defp all_working_revisions(project_slug) do
    case AuthoringResolver.root_container(project_slug) do
      nil -> []
      root -> collect_revisions(project_slug, root, MapSet.new())
    end
  end

  defp collect_revisions(project_slug, %Revision{} = revision, visited) do
    if MapSet.member?(visited, revision.resource_id) do
      []
    else
      visited = MapSet.put(visited, revision.resource_id)

      children =
        revision.children
        |> List.wrap()
        |> Enum.map(&AuthoringResolver.from_resource_id(project_slug, &1))
        |> Enum.reject(&is_nil/1)

      [revision | Enum.flat_map(children, &collect_revisions(project_slug, &1, visited))]
    end
  end

  defp assert_node_type!(nodes, type) do
    unless Enum.any?(nodes, &(&1["type"] == type)) do
      raise "Expected imported Google Docs page to contain a #{inspect(type)} node"
    end
  end

  defp assert_activity_types!(nodes) do
    activity_type_slugs =
      nodes
      |> Enum.filter(&(&1["type"] == "activity-reference"))
      |> Enum.map(& &1["activity_id"])
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&latest_activity_slug!/1)
      |> MapSet.new()

    unless MapSet.subset?(@expected_activity_slugs, activity_type_slugs) do
      raise "Expected activity types #{inspect(MapSet.to_list(@expected_activity_slugs))}, got #{inspect(MapSet.to_list(activity_type_slugs))}"
    end
  end

  defp latest_activity_slug!(resource_id) do
    revision =
      Revision
      |> where([r], r.resource_id == ^resource_id)
      |> order_by([r], desc: r.id)
      |> limit(1)
      |> Repo.one!()

    Activities.get_registration(revision.activity_type_id).slug
  end

  defp collect_nodes(value) when is_list(value), do: Enum.flat_map(value, &collect_nodes/1)

  defp collect_nodes(%{} = value) do
    [value | Enum.flat_map(Map.values(value), &collect_nodes/1)]
  end

  defp collect_nodes(_), do: []

  defp collect_text(value) when is_list(value) do
    value
    |> Enum.map(&collect_text/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp collect_text(%{"text" => text} = value) when is_binary(text) do
    ([text] ++ Enum.map(Map.delete(value, "text") |> Map.values(), &collect_text/1))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp collect_text(%{} = value) do
    value
    |> Map.values()
    |> Enum.map(&collect_text/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp collect_text(value) when is_binary(value), do: value
  defp collect_text(_), do: ""

  defp param!(params, key) do
    case param(params, key, nil) do
      nil -> raise "Expected scenario param #{inspect(key)}"
      value -> value
    end
  end

  defp param(params, key, default) do
    Map.get(params, key) || Map.get(params, existing_atom_key(key)) || default
  end

  defp existing_atom_key(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
