defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Assessments.Projector do
  @moduledoc """
  Non-UI projector for the Assessments tile.
  """

  @histogram_order [
    "0-10",
    "10-20",
    "20-30",
    "30-40",
    "40-50",
    "50-60",
    "60-70",
    "70-80",
    "80-90",
    "90-100"
  ]

  @type grade_row :: %{
          required(:page_id) => pos_integer(),
          optional(:section_resource_id) => pos_integer() | nil,
          optional(:title) => String.t() | nil,
          optional(:container_title) => String.t() | nil,
          optional(:minimum) => number() | nil,
          optional(:median) => number() | nil,
          optional(:mean) => number() | nil,
          optional(:maximum) => number() | nil,
          optional(:standard_deviation) => number() | nil,
          optional(:available_at) => DateTime.t() | NaiveDateTime.t() | nil,
          optional(:due_at) => DateTime.t() | NaiveDateTime.t() | nil,
          optional(:histogram) => map(),
          optional(:completed_count) => non_neg_integer() | nil,
          optional(:total_students) => non_neg_integer() | nil
        }

  @spec build([grade_row()], keyword()) :: map()
  def build(grades_rows, opts \\ []) do
    completion_threshold_pct = Keyword.get(opts, :completion_threshold_pct, 50)
    scope_resource_items = Keyword.get(opts, :scope_resource_items, [])
    total_students_default = Keyword.get(opts, :total_students, 0)
    scope_lookup = scope_resource_lookup(scope_resource_items)

    rows =
      grades_rows
      |> Enum.map(fn row ->
        assessment_id = Map.fetch!(row, :page_id)
        total_students = normalize_count(Map.get(row, :total_students), total_students_default)
        completed_count = normalize_count(Map.get(row, :completed_count), 0)
        ratio = completion_ratio(completed_count, total_students)

        %{
          assessment_id: assessment_id,
          review_resource_id: Map.get(row, :section_resource_id),
          hierarchy_position:
            scope_lookup
            |> Map.get(assessment_id, %{})
            |> Map.get(:hierarchy_position),
          title: assessment_title(row, scope_lookup),
          context_label: context_label(row, scope_lookup),
          available_at: normalize_datetime(Map.get(row, :available_at)),
          due_at: normalize_datetime(Map.get(row, :due_at)),
          completion: %{
            completed_count: completed_count,
            total_students: total_students,
            ratio: ratio,
            label: completion_label(completed_count, total_students),
            status: completion_status(ratio, completion_threshold_pct)
          },
          metrics: %{
            minimum: normalize_metric(Map.get(row, :minimum)),
            median: normalize_metric(Map.get(row, :median)),
            mean: normalize_metric(Map.get(row, :mean)),
            maximum: normalize_metric(Map.get(row, :maximum)),
            standard_deviation: normalize_metric(Map.get(row, :standard_deviation))
          },
          histogram_bins: histogram_bins(Map.get(row, :histogram, %{}))
        }
      end)
      |> sort_rows()

    %{
      rows: rows,
      total_rows: length(rows),
      has_assessments?: rows != []
    }
  end

  defp scope_resource_lookup(scope_resource_items) do
    scope_resource_items
    |> Enum.with_index()
    |> Map.new(fn {item, hierarchy_position} ->
      {
        Map.get(item, :resource_id),
        Map.put(item, :hierarchy_position, hierarchy_position)
      }
    end)
  end

  defp assessment_title(row, scope_lookup) do
    page_id = Map.fetch!(row, :page_id)

    row_title =
      row
      |> Map.get(:title)
      |> normalize_string()

    scope_title =
      scope_lookup
      |> Map.get(page_id, %{})
      |> Map.get(:title)
      |> normalize_string()

    row_title || scope_title || "Assessment #{page_id}"
  end

  defp context_label(row, scope_lookup) do
    page_id = Map.fetch!(row, :page_id)

    row
    |> Map.get(:container_title)
    |> normalize_string()
    |> Kernel.||(
      scope_lookup
      |> Map.get(page_id, %{})
      |> Map.get(:context_label)
      |> normalize_string()
    )
  end

  defp completion_label(completed_count, total_students) do
    "#{completed_count} of #{total_students} students completed"
  end

  defp completion_ratio(_completed_count, 0), do: 0.0

  defp completion_ratio(completed_count, total_students) do
    Float.round(completed_count / total_students, 4)
  end

  defp completion_status(ratio, completion_threshold_pct) do
    if ratio * 100 >= completion_threshold_pct, do: :good, else: :bad
  end

  defp histogram_bins(histogram) when is_map(histogram) do
    Enum.map(@histogram_order, fn range ->
      %{range: range, count: normalize_count(Map.get(histogram, range), 0)}
    end)
  end

  defp histogram_bins(_), do: histogram_bins(%{})

  defp sort_rows(rows) do
    Enum.sort_by(rows, &sort_key/1)
  end

  # Order assessments by their first relevant schedule date (`due_at || available_at`),
  # then preserve curriculum order for ties and for rows with no schedule dates.
  defp sort_key(row) do
    {
      effective_datetime_sort_value(row),
      Map.get(row, :hierarchy_position, 999_999),
      Map.get(row, :assessment_id)
    }
  end

  defp effective_datetime_sort_value(row) do
    case Map.get(row, :due_at) || Map.get(row, :available_at) do
      nil -> {1, 0}
      %DateTime{} = value -> {0, DateTime.to_unix(value, :second)}
    end
  end

  defp normalize_datetime(%DateTime{} = value), do: value

  defp normalize_datetime(%NaiveDateTime{} = value) do
    DateTime.from_naive!(value, "Etc/UTC")
  end

  defp normalize_datetime(_), do: nil

  defp normalize_metric(nil), do: nil
  defp normalize_metric(value) when is_integer(value), do: value * 1.0
  defp normalize_metric(value) when is_float(value), do: Float.round(value, 1)
  defp normalize_metric(_), do: nil

  defp normalize_count(value, _default) when is_integer(value) and value >= 0, do: value
  defp normalize_count(_value, default), do: default

  defp normalize_string(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_string(_), do: nil
end
