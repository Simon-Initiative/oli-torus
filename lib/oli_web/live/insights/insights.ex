defmodule OliWeb.Insights do
  use Phoenix.LiveView
  alias OliWeb.Insights.{TableHeader, TableRow}
  alias Oli.Authoring.Course

  def mount(_params, %{"project_slug" => project_slug} = _session, socket) do
    by_activity_rows = Oli.Analytics.ByActivity.query_against_project_slug(project_slug)
    project = Course.get_project_by_slug(project_slug)

    parent_pages =
      Enum.map(by_activity_rows, fn r -> r.slice.resource_id end)
      |> parent_pages(project_slug)

    {:ok,
     assign(socket,
       project: project,
       by_page_rows: Oli.Analytics.ByPage.query_against_project_slug(project_slug),
       by_activity_rows: by_activity_rows,
       by_objective_rows: Oli.Analytics.ByObjective.query_against_project_slug(project_slug),
       parent_pages: parent_pages,
       selected: :by_activity,
       query: "",
       sort_by: "title",
       sort_order: :asc
     )}
  end

  defp parent_pages(resource_ids, project_slug) do
    publication = Oli.Publishing.project_working_publication(project_slug)
    Oli.Publishing.determine_parent_pages(resource_ids, publication.id)
  end

  def render(assigns) do
    ~L"""
    <ul class="nav nav-pills">
      <li class="nav-item my-2 mr-2">
        <button <%= is_disabled(@selected, :by_activity) %> class="btn btn-primary" phx-click="by-activity">By Activity</button>
      </li>
      <li class="nav-item my-2 mr-2">
        <button <%= is_disabled(@selected, :by_page) %> class="btn btn-primary" phx-click="by-page">By Page</button>
      </li>
      <li class="nav-item my-2 mr-2">
        <button <%= is_disabled(@selected, :by_objective) %> class="btn btn-primary" phx-click="by-objective">By Objective</button>
      </li>
    </ul>
    <div class="card text-center">
      <div class="card-header">
        <form phx-change="search">
          <input type="text" class="form-control" name="query" value="<%= @query %>" placeholder="Search by title..." />
        </form>
      </div>
      <div class="card-body">
        <h5 class="card-title">
          Viewing analytics by <%= case @selected do
          :by_page -> "page"
          :by_activity -> "activity"
          :by_objective -> "objective"
          _ -> "activity"
        end %></h5>
        <table class="table">
          <%= live_component TableHeader, assigns %>
          <tbody>
            <%= for row <- active_rows(assigns) do %>
              <%= live_component TableRow, row: row, parent_pages: assigns.parent_pages, project: assigns.project, selected: @selected %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp active_rows(assigns) do
    case assigns.selected do
      :by_page -> assigns.by_page_rows
      :by_activity -> assigns.by_activity_rows
      :by_objective -> assigns.by_objective_rows
      _ -> assigns.by_activity_rows
    end
    |> filter(assigns.query)
    |> sort(assigns.sort_by, assigns.sort_order)
  end

  defp filter(rows, query) do
    rows |> Enum.filter(&String.match?(&1.slice.title, ~r/#{String.trim(query)}/i))
  end

  # data splits
  def handle_event("by-activity", _event, socket) do
    {:noreply, assign(socket, :selected, :by_activity)}
  end

  def handle_event("by-page", _event, socket) do
    {:noreply, assign(socket, :selected, :by_page)}
  end

  def handle_event("by-objective", _event, socket) do
    {:noreply, assign(socket, :selected, :by_objective)}
  end

  # search
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, query: query)}
  end

  # sorting

  # CLick same column -> reverse sort order
  def handle_event(
        "sort",
        %{"sort-by" => column} = _event,
        %{assigns: %{sort_by: sort_by, sort_order: :asc}} = socket
      )
      when column == sort_by do
    {:noreply, assign(socket, sort_by: sort_by, sort_order: :desc)}
  end

  def handle_event(
        "sort",
        %{"sort-by" => column} = _event,
        %{assigns: %{sort_by: sort_by, sort_order: :desc}} = socket
      )
      when column == sort_by do
    {:noreply, assign(socket, sort_by: sort_by, sort_order: :asc)}
  end

  # Click new column
  def handle_event("sort", %{"sort-by" => column} = _event, socket) do
    {:noreply, assign(socket, sort_by: column)}
  end

  defp sort(rows, "title", :asc), do: rows |> Enum.sort(&(&1.slice.title > &2.slice.title))
  defp sort(rows, "title", :desc), do: rows |> Enum.sort(&(&1.slice.title <= &2.slice.title))
  defp sort(rows, sort_by, :asc), do: rows |> Enum.sort(&(&1[sort_by] > &2[sort_by]))
  defp sort(rows, sort_by, :desc), do: rows |> Enum.sort(&(&1[sort_by] <= &2[sort_by]))

  defp is_disabled(selected, title) do
    if selected == title do
      "disabled"
    else
      ""
    end
  end
end
