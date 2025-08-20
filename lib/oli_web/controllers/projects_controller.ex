defmodule OliWeb.ProjectsController do
  use OliWeb, :controller

  import OliWeb.Common.FormatDateTime

  alias Oli.Authoring.Course
  alias Oli.Repo.Sorting
  alias Oli.Utils.Time

  @doc """
  Export projects as CSV file.
  
  Respects current table filters and sorting from the browse projects page.
  Generates a CSV file with project data and sends it as a download.
  """
  def export_csv(conn, params) do
    author = conn.assigns.current_author
    
    # Extract table state from URL parameters
    sort_by = String.to_existing_atom(params["sort_by"] || "title")
    sort_order = String.to_existing_atom(params["sort_order"] || "asc")
    text_search = params["text_search"] || ""
    show_all = params["show_all"] == "true"
    show_deleted = params["show_deleted"] == "true"
    
    # Build sorting struct
    sorting = %Sorting{direction: sort_order, field: sort_by}
    
    # Build options for the export function
    opts = [
      include_deleted: show_deleted,
      admin_show_all: show_all,
      text_search: text_search
    ]
    
    # Get projects for export
    projects = Course.browse_projects_for_export(author, sorting, opts)
    
    # Transform to CSV
    csv_content = projects_to_csv(projects)
    
    # Generate filename with current date
    filename = "projects-#{Timex.format!(Time.now(), "{YYYY}-{M}-{D}")}.csv"
    
    # Send download
    send_download(conn, {:binary, csv_content}, filename: filename)
  end
  
  defp projects_to_csv(projects) do
    headers = ["Title", "Created", "Created By", "Status"]
    
    rows = Enum.map(projects, fn project ->
      [
        escape_csv_field(project.title || ""),
        date(project.inserted_at, precision: :date),
        escape_csv_field(project.name || ""),
        format_status(project.status)
      ]
    end)
    
    # Combine headers and rows
    [headers | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end
  
  defp escape_csv_field(field) when is_binary(field) do
    if String.contains?(field, [",", "\"", "\n", "\r"]) do
      "\"#{String.replace(field, "\"", "\"\"")}\""
    else
      field
    end
  end
  
  defp escape_csv_field(_field), do: ""
  
  defp format_status(:active), do: "Active"
  defp format_status(:deleted), do: "Deleted"
  defp format_status(status) when is_atom(status), do: status |> Atom.to_string() |> String.capitalize()
  defp format_status(status), do: to_string(status)
end