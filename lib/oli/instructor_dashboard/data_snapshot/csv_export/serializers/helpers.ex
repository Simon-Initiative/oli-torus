defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers do
  @moduledoc false

  @objective_proficiency_weights %{
    "Low" => 20.0,
    "Medium" => 60.0,
    "High" => 100.0
  }

  @spec encode_csv([String.t()], [[term()]]) :: {:ok, binary()}
  def encode_csv(headers, rows) when is_list(headers) and is_list(rows) do
    rows =
      Enum.map(rows, fn
        row when is_list(row) -> Enum.zip(headers, row) |> Enum.into(%{})
        row -> row
      end)

    {:ok, rows |> CSV.encode(headers: headers) |> Enum.join()}
  end

  @spec projection(map(), atom(), [atom()]) :: term()
  def projection(snapshot_bundle, key, path \\ []) do
    value =
      snapshot_bundle
      |> Map.get(:projections, %{})
      |> Map.get(key, %{})
      |> get_in(path)

    if is_nil(value), do: %{}, else: value
  end

  @spec export_request(map()) :: map()
  def export_request(dataset_spec), do: Map.get(dataset_spec, :export_request, %{})

  @spec scope_label(map()) :: String.t()
  def scope_label(dataset_spec) do
    request = export_request(dataset_spec)

    Map.get(request, :dashboard_scope_label) ||
      Map.get(request, :scope_label) ||
      Map.get(request, "dashboard_scope_label") ||
      Map.get(request, "scope_label") ||
      humanize_scope(Map.get(request, :dashboard_scope) || Map.get(request, "dashboard_scope"))
  end

  @spec course_name(map()) :: String.t()
  def course_name(dataset_spec) do
    request = export_request(dataset_spec)

    Map.get(request, :course_name) || Map.get(request, "course_name") || "Course"
  end

  @spec course_section(map()) :: String.t()
  def course_section(dataset_spec) do
    request = export_request(dataset_spec)
    Map.get(request, :course_section) || Map.get(request, "course_section") || "Section"
  end

  @spec timezone(map()) :: String.t()
  def timezone(dataset_spec) do
    request = export_request(dataset_spec)
    Map.get(request, :timezone) || Map.get(request, "timezone") || "Etc/UTC"
  end

  @spec generated_at(map()) :: DateTime.t()
  def generated_at(dataset_spec) do
    request = export_request(dataset_spec)
    Map.get(request, :generated_at) || Map.get(request, "generated_at") || DateTime.utc_now()
  end

  @spec progress_threshold(map()) :: pos_integer()
  def progress_threshold(dataset_spec) do
    request = export_request(dataset_spec)

    Map.get(request, :progress_completion_threshold) ||
      Map.get(request, "progress_completion_threshold") ||
      get_in(request, [:progress_tile_state, :completion_threshold]) ||
      get_in(request, ["progress_tile_state", "completion_threshold"]) ||
      100
  end

  @spec proficiency_definition(map()) :: String.t()
  def proficiency_definition(dataset_spec) do
    request = export_request(dataset_spec)

    Map.get(request, :proficiency_definition) ||
      Map.get(request, "proficiency_definition") ||
      "Learning objective proficiency based on first-attempt correctness"
  end

  @spec total_students(map()) :: non_neg_integer()
  def total_students(snapshot_bundle) do
    summary_total =
      snapshot_bundle
      |> projection(:summary, [:total_students])
      |> normalize_count()

    progress_class_size =
      snapshot_bundle
      |> projection(:progress, [:progress_tile, :class_size])
      |> normalize_count()

    support_total =
      snapshot_bundle
      |> projection(:student_support, [:support, :totals, :total_students])
      |> normalize_count()

    assessments_total =
      snapshot_bundle
      |> projection(:assessments, [:assessments, :rows])
      |> List.wrap()
      |> List.first()
      |> case do
        nil -> 0
        row -> row |> get_in([:completion, :total_students]) |> normalize_count()
      end

    Enum.max([summary_total, progress_class_size, support_total, assessments_total])
  end

  @spec format_metric_number(number() | nil) :: String.t()
  def format_metric_number(nil), do: ""
  def format_metric_number(value) when is_integer(value), do: Integer.to_string(value)

  def format_metric_number(value) when is_float(value) do
    rounded = Float.round(value, 1)

    case rounded do
      whole when whole == trunc(whole) -> Integer.to_string(trunc(whole))
      _ -> :erlang.float_to_binary(rounded, decimals: 1)
    end
  end

  @spec format_one_decimal(number() | nil) :: String.t()
  def format_one_decimal(nil), do: ""

  def format_one_decimal(value) when is_integer(value),
    do: :erlang.float_to_binary(value * 1.0, decimals: 1)

  def format_one_decimal(value) when is_float(value),
    do: :erlang.float_to_binary(Float.round(value, 1), decimals: 1)

  @spec format_bool(boolean() | nil) :: String.t()
  def format_bool(true), do: "True"
  def format_bool(false), do: "False"
  def format_bool(_), do: ""

  @spec format_date(DateTime.t() | NaiveDateTime.t() | nil) :: String.t()
  def format_date(%DateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%d")
  def format_date(%NaiveDateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%d")
  def format_date(_), do: ""

  @spec format_timestamp(DateTime.t()) :: String.t()
  def format_timestamp(%DateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M:%S %Z")

  @spec normalize_category(String.t() | atom() | nil) :: String.t()
  def normalize_category(nil), do: ""

  def normalize_category(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_category()

  def normalize_category(value) when is_binary(value),
    do: value |> String.downcase() |> String.replace(" ", "_")

  @spec flatten_tree_rows([map()]) :: [map()]
  def flatten_tree_rows(rows) do
    Enum.flat_map(rows, fn row ->
      [Map.drop(row, [:children])] ++ flatten_tree_rows(Map.get(row, :children, []))
    end)
  end

  @spec average([number() | nil]) :: float() | nil
  def average(values) do
    values =
      values
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_float/1)

    case values do
      [] -> nil
      _ -> Float.round(Enum.sum(values) / length(values), 1)
    end
  end

  @spec objective_average_proficiency(map() | nil) :: float() | nil
  def objective_average_proficiency(nil), do: nil

  def objective_average_proficiency(distribution) when is_map(distribution) do
    weighted_total =
      Enum.reduce(@objective_proficiency_weights, 0.0, fn {label, weight}, acc ->
        acc + weight * normalize_count(Map.get(distribution, label))
      end)

    student_count =
      @objective_proficiency_weights
      |> Map.keys()
      |> Enum.reduce(0, fn label, acc -> acc + normalize_count(Map.get(distribution, label)) end)

    case student_count do
      0 -> nil
      _ -> Float.round(weighted_total / student_count, 1)
    end
  end

  defp humanize_scope("course"), do: "Entire Course"
  defp humanize_scope("container:" <> _id), do: "Selected Scope"
  defp humanize_scope(_), do: "Selected Scope"

  defp normalize_count(value) when is_integer(value) and value >= 0, do: value
  defp normalize_count(value) when is_float(value) and value >= 0.0, do: trunc(value)
  defp normalize_count(_), do: 0

  defp to_float(value) when is_integer(value), do: value * 1.0
  defp to_float(value) when is_float(value), do: value
end
