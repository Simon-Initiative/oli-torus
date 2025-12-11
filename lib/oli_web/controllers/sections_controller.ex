defmodule OliWeb.SectionsController do
  use OliWeb, :controller

  import OliWeb.Common.Params

  alias Oli.Delivery.Sections.{Browse, BrowseOptions, Section}
  alias Oli.Repo.Sorting
  alias Oli.Utils.Time
  alias OliWeb.Admin.BrowseFilters

  @min_search_length 3
  @type_opts [:open, :lms]
  @max_export_limit 10_000

  @csv_headers [
    "Title",
    "Section ID",
    "Tags",
    "# Enrolled",
    "Cost",
    "Start",
    "End",
    "Base Project/Product",
    "Base ID",
    "Instructors",
    "Institution",
    "Delivery",
    "Status"
  ]

  def export_csv(conn, params) do
    sorting = %Sorting{
      direction: parse_sort_order(params["sort_order"]),
      field: parse_sort_by(params["sort_by"])
    }

    raw_search = params |> get_param("text_search", "") |> String.trim()
    text_search = sanitize_search_term(raw_search)

    filters_state = BrowseFilters.parse(params)
    course_filters = BrowseFilters.to_course_filters(filters_state)

    options = %BrowseOptions{
      text_search: text_search,
      active_today: get_boolean_param(params, "active_today", false),
      filter_status:
        get_atom_param(params, "filter_status", Ecto.Enum.values(Section, :status), nil) ||
          course_filters.status,
      filter_type:
        get_atom_param(params, "filter_type", @type_opts, nil) || course_filters.delivery,
      institution_id: course_filters.institution_id,
      filter_requires_payment: course_filters.requires_payment,
      filter_tag_ids: course_filters.tag_ids,
      filter_date_from: course_filters.date_from,
      filter_date_to: course_filters.date_to,
      filter_date_field: course_filters.date_field,
      blueprint_id: nil,
      project_id: nil
    }

    sections =
      Browse.browse_sections_for_export(sorting, options, @max_export_limit)
      |> Oli.Repo.preload([:tags, :institution, :base_project, :blueprint])

    csv_content = sections_to_csv(sections)
    filename = "sections-" <> Timex.format!(Time.now(), "{YYYY}-{M}-{D}") <> ".csv"

    conn
    |> put_resp_header("content-type", "text/csv")
    |> send_download({:binary, csv_content}, filename: filename)
  end

  defp sections_to_csv(sections) do
    rows =
      Enum.map(sections, fn section ->
        [
          escape_csv_field(format_title(section)),
          escape_csv_field(section.slug || ""),
          escape_csv_field(format_tags(section)),
          escape_csv_field(format_enrollments(section)),
          escape_csv_field(format_cost(section)),
          escape_csv_field(format_datetime(section.start_date)),
          escape_csv_field(format_datetime(section.end_date)),
          escape_csv_field(format_base(section)),
          escape_csv_field(format_base_slug(section)),
          escape_csv_field(format_instructors(section)),
          escape_csv_field(format_institution(section)),
          escape_csv_field(format_delivery(section)),
          escape_csv_field(format_status(section.status))
        ]
      end)

    encode_csv(@csv_headers, rows)
  end

  defp encode_csv(headers, rows) do
    [headers | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp parse_sort_by("title"), do: :title
  defp parse_sort_by("enrollments_count"), do: :enrollments_count
  defp parse_sort_by("requires_payment"), do: :requires_payment
  defp parse_sort_by("start_date"), do: :start_date
  defp parse_sort_by("end_date"), do: :end_date
  defp parse_sort_by("base"), do: :base
  defp parse_sort_by("instructor"), do: :instructor
  defp parse_sort_by("institution"), do: :institution
  defp parse_sort_by("type"), do: :type
  defp parse_sort_by("status"), do: :status
  defp parse_sort_by(_), do: :start_date

  defp parse_sort_order("desc"), do: :desc
  defp parse_sort_order(_), do: :asc

  defp sanitize_search_term(nil), do: ""

  defp sanitize_search_term(search) when is_binary(search) do
    trimmed = String.trim(search)

    cond do
      trimmed == "" -> ""
      String.length(trimmed) < @min_search_length -> ""
      true -> trimmed
    end
  end

  defp format_title(section), do: section.title || ""

  defp format_tags(nil), do: ""

  defp format_tags(%Section{} = section) do
    section
    |> Map.get(:tags, [])
    |> Enum.map(&Map.get(&1, :name, ""))
    |> Enum.join(", ")
  end

  defp format_tags(tags) when is_list(tags),
    do: tags |> Enum.map(&Map.get(&1, :name, "")) |> Enum.join(", ")

  defp format_tags(_), do: ""

  defp format_enrollments(section), do: section.enrollments_count || 0

  defp format_cost(%Section{requires_payment: true, amount: amount}) do
    case Money.to_string(amount) do
      {:ok, value} -> value
      _ -> "Yes"
    end
  end

  defp format_cost(%Section{requires_payment: false}), do: "None"
  defp format_cost(_), do: ""

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S %Z")

  defp format_datetime(%NaiveDateTime{} = datetime) do
    case DateTime.from_naive(datetime, "Etc/UTC") do
      {:ok, dt} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S %Z")
      _ -> ""
    end
  end

  defp format_datetime(_), do: ""

  defp format_base(section) do
    cond do
      section.blueprint && section.blueprint.title ->
        section.blueprint.title

      section.base_project && section.base_project.title ->
        section.base_project.title

      true ->
        ""
    end
  end

  defp format_base_slug(section) do
    cond do
      section.blueprint && section.blueprint.slug ->
        section.blueprint.slug

      section.base_project && section.base_project.slug ->
        section.base_project.slug

      true ->
        ""
    end
  end

  defp format_instructors(section), do: Map.get(section, :instructor_name, "")

  defp format_institution(section) do
    Map.get(section, :institution_name) ||
      case section.institution do
        nil -> ""
        institution -> institution.name
      end
  end

  defp format_delivery(%Section{open_and_free: true}), do: "DD"
  defp format_delivery(%Section{open_and_free: false}), do: "LTI"
  defp format_delivery(_), do: ""

  defp format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_status(status), do: to_string(status)

  defp escape_csv_field(field) when is_binary(field) do
    safe = csv_safe(field)

    if String.contains?(safe, [",", "\"", "\n", "\r"]) do
      "\"#{String.replace(safe, "\"", "\"\"")}\""
    else
      safe
    end
  end

  defp escape_csv_field(field) do
    field
    |> to_string()
    |> escape_csv_field()
  rescue
    _ -> ""
  end

  defp csv_safe(value) do
    s = to_string(value || "")
    if String.starts_with?(s, ["=", "+", "-", "@", "\t"]), do: "'" <> s, else: s
  end
end
