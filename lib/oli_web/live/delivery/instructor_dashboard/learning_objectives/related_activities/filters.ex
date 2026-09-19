defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.Filters do
  @moduledoc """
  Request parameters, filtering, sorting and pagination for the Linked Activities page.

  Pure functions over already-loaded activity rows, so the LiveView keeps only its own
  lifecycle and assigns.
  """

  alias OliWeb.Common.Params
  alias OliWeb.Delivery.ActivityHelpers

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil,
    selected_attempts_ids: Jason.encode!([])
  }

  @doc "The page's default request parameters."
  def default_params, do: @default_params

  @doc "Decodes request parameters, mapping legacy sort names onto the current ones."
  def decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(
          params,
          "sort_order",
          [:asc, :desc],
          @default_params.sort_order
        ),
      sort_by:
        params
        |> Params.get_atom_param(
          "sort_by",
          [:title, :total_attempts, :avg_score, :question_stem, :attempts, :percent_correct],
          :title
        )
        |> normalize_sort_by(),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      selected_attempts_ids:
        Params.get_param(params, "selected_attempts_ids", @default_params.selected_attempts_ids),
      avg_score_percentage: Params.get_int_param(params, "avg_score_percentage", nil),
      avg_score_selector:
        Params.get_atom_param(
          params,
          "avg_score_selector",
          [:is_equal_to, :is_less_than_or_equal, :is_greather_than_or_equal],
          nil
        ),
      back_params: back_url_params(params)
    }
  end

  @doc "Filters, sorts and paginates rows, returning the total before pagination."
  def apply(activities, params) do
    filtered_activities =
      activities
      |> maybe_filter_by_text(params.text_search)
      |> maybe_filter_by_attempts(decode_attempts_ids(params.selected_attempts_ids))
      |> maybe_filter_by_score(params.avg_score_selector, params.avg_score_percentage)
      |> sort_by(params.sort_by, params.sort_order)

    total_count = length(filtered_activities)

    paginated_activities =
      filtered_activities
      |> Enum.drop(params.offset)
      |> Enum.take(params.limit)

    {total_count, paginated_activities}
  end

  @doc "Decodes the JSON-encoded attempts filter selection."
  def decode_attempts_ids(encoded) when is_binary(encoded) do
    case Jason.decode(encoded) do
      {:ok, ids} when is_list(ids) -> ids
      _ -> []
    end
  end

  def decode_attempts_ids(_), do: []

  @doc "Marks the attempts filter options that are currently selected."
  def attempts_options(selected_ids) do
    Enum.map(ActivityHelpers.attempts_filter_options(), &%{&1 | selected: &1.id in selected_ids})
  end

  @doc "Maps the selected attempts filter options by id."
  def selected_attempts_options(selected_ids) do
    ActivityHelpers.attempts_filter_options()
    |> Enum.filter(&(&1.id in selected_ids))
    |> Map.new(&{&1.id, &1.name})
  end

  @doc "Decodes the parameters the page returns to when navigating back to Learning Objectives."
  def back_url_params(params), do: decode_back_params(Map.get(params, "back_params"))

  defp decode_back_params(decoded) when is_map(decoded), do: decoded

  defp decode_back_params(encoded) when is_binary(encoded) do
    encoded |> URI.decode() |> Jason.decode() |> decoded_object()
  end

  defp decode_back_params(_), do: %{}

  defp decoded_object({:ok, decoded}) when is_map(decoded), do: decoded
  defp decoded_object(_), do: %{}

  @doc "Toggles the sort order when the same column is selected again."
  def update_params(%{sort_by: current_sort_by, sort_order: current_sort_order} = params, %{
        sort_by: new_sort_by
      })
      when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  def update_params(params, new_param) do
    Map.merge(params, new_param)
  end

  defp maybe_filter_by_text(activities, nil), do: activities
  defp maybe_filter_by_text(activities, ""), do: activities

  defp maybe_filter_by_text(activities, text_search) do
    Enum.filter(activities, fn activity ->
      search = String.downcase(text_search)
      stem = String.downcase(activity.question_stem || "")
      title = String.downcase(activity.title || "")

      String.contains?(stem, search) or String.contains?(title, search)
    end)
  end

  defp maybe_filter_by_attempts(activities, []), do: activities

  defp maybe_filter_by_attempts(activities, selected_ids) do
    Enum.filter(activities, fn activity ->
      # Mirrors the `Pages` predicates, where "Less than 5" also includes zero attempts.
      Enum.any?(selected_ids, fn
        1 -> activity.total_attempts in [nil, 0]
        2 -> not is_nil(activity.total_attempts) and activity.total_attempts <= 5
        3 -> not is_nil(activity.total_attempts) and activity.total_attempts > 5
        _ -> false
      end)
    end)
  end

  defp maybe_filter_by_score(activities, nil, _), do: activities
  defp maybe_filter_by_score(activities, _, nil), do: activities

  defp maybe_filter_by_score(activities, selector, percentage) do
    Enum.filter(activities, fn activity ->
      score = round((activity.avg_score || 0.0) * 100)

      case selector do
        :is_equal_to -> score == percentage
        :is_less_than_or_equal -> score <= percentage
        :is_greather_than_or_equal -> score >= percentage
      end
    end)
  end

  defp sort_by(activities, :title, sort_order) do
    Enum.sort_by(activities, &String.downcase(&1.title || ""), sort_order)
  end

  defp sort_by(activities, :total_attempts, sort_order) do
    Enum.sort_by(activities, &(&1.total_attempts || 0), sort_order)
  end

  defp sort_by(activities, :avg_score, sort_order) do
    Enum.sort_by(activities, &(&1.avg_score || 0), sort_order)
  end

  defp sort_by(activities, _sort_by, _sort_order), do: activities

  defp normalize_sort_by(:question_stem), do: :title
  defp normalize_sort_by(:attempts), do: :total_attempts
  defp normalize_sort_by(:percent_correct), do: :avg_score
  defp normalize_sort_by(sort_by), do: sort_by
end
