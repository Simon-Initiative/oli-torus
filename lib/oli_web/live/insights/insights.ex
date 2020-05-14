defmodule OliWeb.Insights do
  use Phoenix.LiveView

  import Ecto.Query, warn: false

  alias Phoenix.PubSub
  alias OliWeb.Insights.TableRow

  def mount(_params, %{ "project_id" => project_id } = _session, socket) do

    # PubSub.subscribe Oli.PubSub, "resource:" <> Integer.to_string(resource_id)

    # Questions:
    #   What should links point to for each of the rows? For an activity, what do we link to?
    #      A page with the activity in edit mode?


    {:ok, assign(socket,
      by_page_rows: [],
      by_activity_rows: Oli.Analytics.ByActivity.query_against_project_id(project_id),
      by_objective_rows: Oli.Analytics.ByObjective.query_against_project_id(project_id),
      selected: :by_activity,
      query: nil,
      sort_by: "title",
      sort_order: :asc
    )}
  end

  def render(assigns) do

    ~L"""
    <div class="card text-center">
      <div class="card-header">
        <ul class="nav nav-tabs card-header-tabs">
          <li class="nav-item">
            <button class="btn btn-primary" phx-click="by-page">By Page</button>
          </li>
          <li class="nav-item">
            <button class="btn btn-primary" phx-click="by-activity">By Activity</button>
          </li>
          <li class="nav-item">
            <button class="btn btn-primary" phx-click="by-objective">By Objective</button>
          </li>
        </ul>
        <form phx-change="search"><input type="text" name="query" value="<%= @query %>" placeholder="Search by title..." /></form>
      </div>
      <div class="card-body">
        <h5 class="card-title">
          <%= case @selected do
          :by_page -> "View analytics by page"
          :by_activity -> "View analytics by activity"
          :by_objective -> "View analytics by objective"
          _ -> "View analytics by activity"
        end %></h5>
        <table class="table">
          <thead>
            <tr>
              <th style="cursor: pointer" scope="col" phx-click="sort" phx-value-sort-by="title">
                <%= case @selected do
                  :by_page -> "Page"
                  :by_activity -> "Activity"
                  :by_objective -> "Objective"
                  _ -> "Objective"
                end %>
                <%= sort_order_icon("title", @sort_by, @sort_order) %>
              </th>
              <th style="cursor: pointer" phx-click="sort" phx-value-sort-by="number_of_attempts" scope="col">
                Number of Attempts
                <%= sort_order_icon("number_of_attempts", @sort_by, @sort_order) %>
              </th>
              <th style="cursor: pointer" phx-click="sort" phx-value-sort-by="relative_difficulty" scope="col">
                Relative Difficulty
                <%= sort_order_icon("relative_difficulty", @sort_by, @sort_order) %>
              </th>
              <th style="cursor: pointer" phx-click="sort" phx-value-sort-by="eventually_correct" scope="col">
                Eventually Correct
                <%= sort_order_icon("eventually_correct", @sort_by, @sort_order) %>
              </th>
              <th style="cursor: pointer" phx-click="sort" phx-value-sort-by="first_try_correct" scope="col">
                First Try Correct
                <%= sort_order_icon("first_try_correct", @sort_by, @sort_order) %>
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for {row, i} <- Enum.with_index(
              case @selected do
                :by_page -> @by_page_rows
                :by_activity -> @by_activity_rows
                :by_objective -> @by_objective_rows
                _ -> @by_activity_rows
              end
              |> filter(@query)
              |> sort(@sort_by, @sort_order)
            )
               do %>
            <%= live_component @socket, TableRow,
              index: i,
              row: row %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp filter(rows, query) do
    rows |> Enum.filter(& String.match?(&1.slice.title, ~r/#{query}/i))
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
  def handle_event("sort", %{"sort-by" => column} = _event, %{assigns: %{sort_by: sort_by, sort_order: :asc}} = socket) when column == sort_by do
    {:noreply, assign(socket, sort_by: sort_by, sort_order: :desc)}
  end
  def handle_event("sort", %{"sort-by" => column} = _event, %{assigns: %{sort_by: sort_by, sort_order: :desc}} = socket) when column == sort_by do
    {:noreply, assign(socket, sort_by: sort_by, sort_order: :asc)}
  end

  # Click new column
  def handle_event("sort", %{"sort-by" => column} = _event, socket) do
    {:noreply, assign(socket, sort_by: column)}
  end

  defp sort(rows, sort_by, :asc), do: rows |> Enum.sort(& &1[sort_by] > &2[sort_by] )
  defp sort(rows, sort_by, :desc), do: rows |> Enum.sort(& &1[sort_by] <= &2[sort_by])

  defp sort_order_icon(column, sort_by, :asc) when column == sort_by, do: "▲"
  defp sort_order_icon(column, sort_by, :desc) when column == sort_by, do: "▼"
  defp sort_order_icon(_, _, _), do: ""

end
