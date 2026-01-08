defmodule OliWeb.ProductsController do
  use OliWeb, :controller

  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Utils.Time
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
    filename = "products-#{Timex.format!(Time.now(), "{YYYY}-{M}-{D}")}.csv"

    conn
    |> put_resp_header("content-type", "text/csv")
    |> send_download({:binary, csv_content}, filename: filename)
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
end
