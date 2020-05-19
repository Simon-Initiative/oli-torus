defmodule OliWeb.Insights.TableHeader do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <thead>
      <tr>
        <th style="cursor: pointer" phx-click="sort" phx-value-sort-by="title" scope="col">
          <%= case @selected do
            :by_page -> "Page"
            :by_activity -> "Activity"
            :by_objective -> "Objective"
            _ -> "Objective"
          end %>
          <%= sort_order_icon("title", @sort_by, @sort_order) %>
        </th>
        <%= if @selected == :by_page || @selected == :by_objective do %>
          <th scope="col">Activity Title</th>
        <% end %>
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
    """
  end

  defp sort_order_icon(column, sort_by, :asc) when column == sort_by, do: "▲"
  defp sort_order_icon(column, sort_by, :desc) when column == sort_by, do: "▼"
  defp sort_order_icon(_, _, _), do: ""
end
