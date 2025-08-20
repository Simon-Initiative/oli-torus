defmodule OliWeb.ProjectsController do
  use OliWeb, :controller


  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Repo.Sorting
  alias Oli.Utils.Time

  @csv_headers ["Title", "Created", "Created By", "Status"]

  @doc """
  Export projects as CSV file.
  
  Respects current table filters and sorting from the browse projects page.
  Generates a CSV file with project data and sends it as a download.
  """
  def export_csv(conn, params) do
    author = conn.assigns.current_author
    is_content_admin = Accounts.has_admin_role?(author, :content_admin)
    
    # Extract table state from URL parameters with validation
    sort_by = case params["sort_by"] do
      "title" -> :title
      "inserted_at" -> :inserted_at
      "status" -> :status
      "name" -> :name
      _ -> :title
    end
    
    sort_order = case params["sort_order"] do
      "asc" -> :asc
      "desc" -> :desc
      _ -> :asc
    end
    text_search = params["text_search"] || ""
    
    # Handle show_all with proper defaults like the LiveView
    show_all = case params["show_all"] do
      "true" -> true
      "false" -> false
      nil -> 
        if is_content_admin,
          do: Accounts.get_author_preference(author, :admin_show_all_projects, true),
          else: true
    end
    
    # Handle show_deleted with proper defaults
    show_deleted = case params["show_deleted"] do
      "true" -> true
      "false" -> false
      nil -> Accounts.get_author_preference(author, :admin_show_deleted_projects, false)
    end
    
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
    
    # Send download with proper content type
    conn
    |> put_resp_header("content-type", "text/csv")
    |> send_download({:binary, csv_content}, filename: filename)
  end
  
  defp projects_to_csv(projects) do
    headers = @csv_headers
    
    rows = Enum.map(projects, fn project ->
      [
        escape_csv_field(project.title || ""),
        escape_csv_field(Date.to_string(DateTime.to_date(project.inserted_at))),
        escape_csv_field(project.name || ""),
        escape_csv_field(format_status(project.status))
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