defmodule OliWeb.Workspaces.CourseAuthor.Datasets.Common do
  use OliWeb, :html

  def age_warning(assigns) do
    ~H"""
    <div class="alert alert-info mt-5" role="alert">
      <strong>Note:</strong> Dataset results can trail behind student activity by up to 24 hours.
    </div>
    """
  end

  def job_type_label(%{job_type: :datashop}), do: "Datashop"
  def job_type_label(%{job_type: "datashop"}), do: "Datashop"

  def job_type_label(%{job_type: :custom} = job), do: custom_job_type_label(job)
  def job_type_label(%{job_type: "custom"} = job), do: custom_job_type_label(job)
  def job_type_label(_), do: "Custom"

  defp custom_job_type_label(%{configuration: config}) do
    event_type = config_value(config, :event_type)
    event_sub_types = config_value(config, :event_sub_types, []) |> normalize_list()
    excluded_fields = config_value(config, :excluded_fields, []) |> normalize_list()

    case event_type do
      "page_viewed" ->
        "Page views"

      "video" ->
        "Video"

      "attempt_evaluated" ->
        cond do
          required_survey_event_sub_types?(event_sub_types) ->
            "Required survey"

          performance_event_sub_types?(event_sub_types) and excluded_fields == [] ->
            "Performance (extended)"

          performance_event_sub_types?(event_sub_types) ->
            "Performance"

          true ->
            "Performance"
        end

      _ ->
        "Custom"
    end
  end

  defp custom_job_type_label(_), do: "Custom"

  defp config_value(config, key, default \\ nil)

  defp config_value(nil, _key, default), do: default

  defp config_value(%_{} = config, key, default),
    do: Map.get(config, key, default)

  defp config_value(config, key, default) when is_map(config) do
    Map.get(config, key, Map.get(config, Atom.to_string(key), default))
  end

  defp normalize_list(list) when is_list(list), do: list
  defp normalize_list(_), do: []

  defp required_survey_event_sub_types?(event_sub_types),
    do: MapSet.new(event_sub_types) == MapSet.new(["part_attempt_evaluated"])

  defp performance_event_sub_types?(event_sub_types),
    do:
      MapSet.new(event_sub_types) ==
        MapSet.new([
          "part_attempt_evaluated",
          "activity_attempt_evaluated",
          "page_attempt_evaluated"
        ])
end
