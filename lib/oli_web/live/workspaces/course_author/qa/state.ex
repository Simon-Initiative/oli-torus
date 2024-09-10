defmodule OliWeb.Workspaces.CourseAuthor.Qa.State do
  alias OliWeb.Common.SessionContext

  @default_filters MapSet.new(["pedagogy", "content", "accessibility", "equity"])

  @default_state %{
    active: :review,
    filters: @default_filters,
    filtered_warnings: [],
    warnings: [],
    qa_reviews: [],
    parent_pages: %{},
    warnings_by_type: %{},
    warning_types: [],
    project: nil,
    author: nil
  }

  def from_params(state, params) do
    filters =
      case params["filters"] do
        nil -> @default_filters
        s -> String.split(s, ",") |> MapSet.new()
      end

    selected_id =
      case params["selected"] do
        nil ->
          if is_nil(state.selected), do: nil, else: state.selected.id

        id ->
          id
      end

    state = Map.merge(state, Map.new(selection_changed(state, selected_id)))
    set_filters(state, filters)
  end

  @spec to_params(MapSet.t(any), any) :: %{filters: binary, selected: any}
  def to_params(filters, selected) do
    %{
      filters: MapSet.to_list(filters) |> Enum.join(","),
      selected: selected
    }
  end

  def initialize_state(
        %SessionContext{author: author} = ctx,
        project,
        initial_review
      ) do
    changes =
      Keyword.merge(
        [
          project: project,
          author: author,
          ctx: ctx,
          title: "Review | " <> project.title
        ],
        new_review_ran(@default_state, initial_review)
      )
      |> Enum.reduce(%{}, fn {k, v}, m -> Map.put(m, k, v) end)

    Map.merge(@default_state, changes)
  end

  def new_review_ran(state, {warnings, parent_pages, qa_reviews}) do
    Keyword.merge(
      [
        selected: nil,
        qa_reviews: qa_reviews,
        parent_pages: parent_pages
      ],
      update_warnings(state, warnings)
    )
  end

  def toggle_filter(state, filter_type) do
    if MapSet.member?(state.filters, filter_type) do
      MapSet.delete(state.filters, filter_type)
    else
      MapSet.put(state.filters, filter_type)
    end
  end

  def set_filters(state, filters) do
    filtered_warnings = filter_warnings(filters, state.warnings)

    selected =
      case Enum.find(filtered_warnings, fn w -> w == state.selected end) do
        nil -> Enum.at(filtered_warnings, 0, nil)
        item -> item
      end

    [
      filtered_warnings: filtered_warnings,
      filters: filters,
      selected: selected
    ]
  end

  def selection_changed(_, nil), do: []
  def selection_changed(_, ""), do: []

  def selection_changed(state, warning_id) do
    warning_id = if is_binary(warning_id), do: String.to_integer(warning_id), else: warning_id
    [selected: Enum.find(state.warnings, fn r -> r.id == warning_id end)]
  end

  def warning_dismissed(state, warning_id) do
    warnings = Enum.filter(state.warnings, fn %{id: id} -> id !== warning_id end)

    selected =
      case state.selected do
        nil -> nil
        %{id: ^warning_id} -> select_another(state.filtered_warnings, state.selected)
        _ -> state.selected
      end

    Keyword.merge(
      [
        selected: selected
      ],
      update_warnings(state, warnings)
    )
  end

  def warning_arrived(state, warning) do
    warnings =
      case Enum.find(state.warnings, nil, fn %{id: id} -> id == warning.id end) do
        nil -> state.warnings
        _ -> [warning | state.warnings]
      end

    update_warnings(state, warnings)
  end

  defp filter_warnings(filters, warnings) do
    Enum.filter(warnings, fn w -> MapSet.member?(filters, w.review.type) end)
  end

  defp update_warnings(state, active_warnings) do
    warnings =
      active_warnings
      |> Enum.sort_by(&{&1.review.type, &1.subtype})

    warnings_by_type =
      warnings
      |> Enum.group_by(& &1.review.type)

    warning_types = Map.keys(warnings_by_type)

    [
      filtered_warnings: filter_warnings(state.filters, warnings),
      warnings: warnings,
      warnings_by_type: warnings_by_type,
      warning_types: warning_types
    ]
  end

  defp select_another(warnings, item) do
    index = Enum.find_index(warnings, fn w -> w == item end)
    last_index = length(warnings) - 1

    case {last_index, index} do
      {0, _} -> nil
      {last, last} -> Enum.at(warnings, last - 1)
      {_, index} -> Enum.at(warnings, index + 1)
    end
  end
end
