defmodule OliWeb.ProductsController do
  use OliWeb, :controller

  import OliWeb.Common.Params

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Blueprint, Browse, BrowseOptions, Section}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Utils
  alias OliWeb.Admin.BrowseFilters

  @csv_headers [
    "Title",
    "Product ID",
    "Tags",
    "Created",
    "Requires Payment",
    "Base Project",
    "Base Project ID",
    "Status"
  ]

  @usage_csv_headers_admin [
    "Title",
    "Section ID",
    "Tags",
    "# Enrolled",
    "Cost",
    "Start",
    "End",
    "Project Version",
    "Instructors",
    "Institution",
    "Delivery",
    "Status"
  ]

  @usage_csv_headers_non_admin [
    "Title",
    "Section ID",
    "# Enrolled",
    "Cost",
    "Start",
    "End",
    "Project Version",
    "Instructors",
    "Institution",
    "Delivery",
    "Status"
  ]

  # Configurable safety limit
  @max_export_limit 10_000
  @min_search_length 3

  @doc """
  Export products as CSV file.

  Respects current table filters and sorting from the browse products page.
  Generates a CSV file with product data and sends it as a download.
  """

  def export_csv(conn, params) do
    sort_by =
      case params["sort_by"] do
        "title" -> :title
        "inserted_at" -> :inserted_at
        "requires_payment" -> :requires_payment
        "base_project_id" -> :base_project_id
        "status" -> :status
        _ -> :inserted_at
      end

    sort_order =
      case params["sort_order"] do
        "asc" -> :asc
        "desc" -> :desc
        _ -> :desc
      end

    text_search =
      params
      |> Map.get("text_search", "")
      |> sanitize_search_term()

    include_archived = boolean_param(params["include_archived"], false)

    filter_state = BrowseFilters.parse(params)
    course_filters = BrowseFilters.to_course_filters(filter_state)

    paging = %Paging{offset: 0, limit: @max_export_limit}
    sorting = %Sorting{direction: sort_order, field: sort_by}

    opts = [
      text_search: text_search,
      include_archived: include_archived,
      project_id: parse_int(params["project_id"]),
      filter_requires_payment: course_filters.requires_payment,
      filter_tag_ids: course_filters.tag_ids,
      filter_date_from: course_filters.date_from,
      filter_date_to: course_filters.date_to,
      filter_date_field: course_filters.date_field,
      filter_status: course_filters.status,
      institution_id: course_filters.institution_id
    ]

    products =
      paging
      |> Blueprint.browse(sorting, opts)
      |> Repo.preload([:base_project, :tags])

    csv_content = products_to_csv(products)
    filename = "products-#{Date.utc_today() |> Date.to_iso8601()}.csv"

    conn
    |> put_resp_header("content-type", "text/csv")
    |> send_download({:binary, csv_content}, filename: filename)
  end

  def export_usage_csv(conn, %{"product_id" => product_slug} = params) do
    author = conn.assigns.current_author
    is_admin = Accounts.at_least_content_admin?(author)

    with {:ok, product} <- fetch_product(product_slug),
         :ok <- authorize_product_usage_export(author, product) do
      sorting = %Sorting{
        direction: parse_usage_sort_order(params["sort_order"]),
        field: parse_usage_sort_by(params["sort_by"])
      }

      raw_search = params |> get_param("text_search", "") |> String.trim()
      text_search = sanitize_search_term(raw_search)

      filter_state = BrowseFilters.parse(params)
      course_filters = BrowseFilters.to_course_filters(filter_state)

      options = %BrowseOptions{
        text_search: text_search,
        active_today: get_boolean_param(params, "active_today", false),
        filter_status:
          get_safe_atom_param(params, "filter_status", Ecto.Enum.values(Section, :status), nil) ||
            course_filters.status,
        filter_type:
          get_safe_atom_param(params, "filter_type", [:open, :lms], nil) ||
            course_filters.delivery,
        institution_id: course_filters.institution_id,
        filter_requires_payment: course_filters.requires_payment,
        filter_tag_ids: course_filters.tag_ids,
        filter_date_from: course_filters.date_from,
        filter_date_to: course_filters.date_to,
        filter_date_field: course_filters.date_field,
        blueprint_id: product.id,
        project_id: nil
      }

      sections =
        Browse.browse_sections_for_export(sorting, options, @max_export_limit)
        |> Repo.preload(usage_export_preloads(is_admin))

      csv_content = sections_to_usage_csv(sections, is_admin)
      filename = "template-usage-" <> (Date.utc_today() |> Date.to_iso8601()) <> ".csv"

      conn
      |> put_resp_header("content-type", "text/csv")
      |> send_download({:binary, csv_content}, filename: filename)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Template not found"})

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You are not authorized to access this page.")
        |> redirect(to: "/workspaces/course_author")
    end
  end

  defp products_to_csv(products) do
    rows =
      Enum.map(products, fn product ->
        [
          escape_csv_field(csv_safe(product.title)),
          escape_csv_field(csv_safe(product.slug)),
          escape_csv_field(csv_safe(format_tags(product.tags))),
          escape_csv_field(format_created(product.inserted_at)),
          escape_csv_field(format_payment(product)),
          escape_csv_field(csv_safe(product.base_project && product.base_project.title)),
          escape_csv_field(csv_safe(product.base_project && product.base_project.slug)),
          escape_csv_field(format_status(product.status))
        ]
      end)

    [@csv_headers | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp format_created(nil), do: ""

  defp format_created(datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_string()
  end

  defp format_payment(%{requires_payment: false}), do: "None"

  defp format_payment(%{requires_payment: true, amount: amount}) do
    case Money.to_string(amount) do
      {:ok, value} -> value
      _ -> "Yes"
    end
  end

  defp format_payment(_), do: ""

  defp format_tags(%Ecto.Association.NotLoaded{}), do: ""
  defp format_tags(nil), do: ""

  defp format_tags(tags) when is_list(tags) do
    tags
    |> Enum.map(& &1.name)
    |> Enum.sort()
    |> Enum.join(", ")
  end

  defp format_tags(_), do: ""

  defp format_status(status) when is_atom(status),
    do: status |> Atom.to_string() |> String.capitalize()

  defp format_status(status), do: to_string(status)

  defp escape_csv_field(field) when is_binary(field) do
    if String.contains?(field, [",", "\"", "\n", "\r"]) do
      "\"#{String.replace(field, "\"", "\"\"")}\""
    else
      field
    end
  end

  defp escape_csv_field(field) when is_nil(field), do: ""
  defp escape_csv_field(field), do: field |> to_string()

  defp csv_safe(value) do
    s = to_string(value || "")

    if String.starts_with?(s, ["=", "+", "-", "@", "\t"]), do: "'" <> s, else: s
  end

  defp sanitize_search_term(nil), do: ""

  defp sanitize_search_term(search) when is_binary(search) do
    trimmed = String.trim(search)

    cond do
      trimmed == "" -> ""
      String.length(trimmed) < @min_search_length -> ""
      true -> trimmed
    end
  end

  defp sanitize_search_term(_), do: ""

  defp boolean_param("true", _default), do: true
  defp boolean_param("false", _default), do: false
  defp boolean_param(_, default), do: default

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp fetch_product(product_slug) do
    case Sections.get_section_by_slug_with_base_project(product_slug) do
      %Section{type: :blueprint} = product -> {:ok, product}
      _ -> {:error, :not_found}
    end
  end

  defp authorize_product_usage_export(nil, _product), do: {:error, :unauthorized}

  defp authorize_product_usage_export(author, %Section{} = product) do
    if Accounts.at_least_content_admin?(author) or
         Blueprint.is_author_of_blueprint?(product.slug, author.id) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp sections_to_usage_csv(sections, true) do
    rows =
      Enum.map(sections, fn section ->
        [
          escape_csv_field(csv_safe(section.title)),
          escape_csv_field(csv_safe(section.slug)),
          escape_csv_field(csv_safe(format_tags(section.tags))),
          escape_csv_field(format_enrollments(section)),
          escape_csv_field(format_cost(section)),
          escape_csv_field(format_datetime(section.start_date)),
          escape_csv_field(format_datetime(section.end_date)),
          escape_csv_field(format_project_version(section)),
          escape_csv_field(csv_safe(format_instructors(section))),
          escape_csv_field(csv_safe(format_institution(section))),
          escape_csv_field(format_delivery(section)),
          escape_csv_field(format_section_status(section.status))
        ]
      end)

    [@usage_csv_headers_admin | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp sections_to_usage_csv(sections, false) do
    rows =
      Enum.map(sections, fn section ->
        [
          escape_csv_field(csv_safe(section.title)),
          escape_csv_field(csv_safe(section.slug)),
          escape_csv_field(format_enrollments(section)),
          escape_csv_field(format_cost(section)),
          escape_csv_field(format_datetime(section.start_date)),
          escape_csv_field(format_datetime(section.end_date)),
          escape_csv_field(format_project_version(section)),
          escape_csv_field(csv_safe(format_instructors(section))),
          escape_csv_field(csv_safe(format_institution(section))),
          escape_csv_field(format_delivery(section)),
          escape_csv_field(format_section_status(section.status))
        ]
      end)

    [@usage_csv_headers_non_admin | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp parse_usage_sort_by("title"), do: :title
  defp parse_usage_sort_by("enrollments_count"), do: :enrollments_count
  defp parse_usage_sort_by("requires_payment"), do: :requires_payment
  defp parse_usage_sort_by("start_date"), do: :start_date
  defp parse_usage_sort_by("end_date"), do: :end_date
  defp parse_usage_sort_by("instructor"), do: :instructor
  defp parse_usage_sort_by("institution"), do: :institution
  defp parse_usage_sort_by("type"), do: :type
  defp parse_usage_sort_by("status"), do: :status
  defp parse_usage_sort_by(_), do: :start_date

  defp parse_usage_sort_order("desc"), do: :desc
  defp parse_usage_sort_order(_), do: :asc

  defp get_safe_atom_param(params, name, valid, default_value)
       when is_list(valid) and is_binary(name) do
    case params[name] do
      nil ->
        default_value

      value when is_binary(value) ->
        Enum.find(valid, default_value, &(Atom.to_string(&1) == value))

      _ ->
        default_value
    end
  end

  defp usage_export_preloads(true),
    do: [:tags, :institution, section_project_publications: :publication]

  defp usage_export_preloads(false),
    do: [:institution, section_project_publications: :publication]

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

  defp format_project_version(%Section{} = section) do
    section
    |> Map.get(:section_project_publications, [])
    |> Enum.find(fn spp ->
      spp.project_id == section.base_project_id and match?(%Publication{}, spp.publication)
    end)
    |> case do
      nil ->
        "N/A"

      spp ->
        Utils.render_version(
          spp.publication.edition,
          spp.publication.major,
          spp.publication.minor
        )
    end
  end

  defp format_project_version(_), do: "N/A"

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

  defp format_section_status(status) when is_atom(status),
    do: status |> Atom.to_string() |> String.capitalize()

  defp format_section_status(status), do: to_string(status)
end
