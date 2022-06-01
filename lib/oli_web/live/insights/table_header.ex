defmodule OliWeb.Insights.TableHeader do
  use Phoenix.LiveComponent

  def th(assigns, sort_by, title, tooltip) do
    ~L"""
    <th
      tabindex="0"
      style="cursor: pointer"
      phx-click="sort"
      phx-keyup="sort"
      phx-value-sort-by="<%= sort_by %>"
      scope="col"
      data-trigger="hover focus"
      data-toggle=<%= if tooltip do "popover" else "" end %>
      data-placement="top"
      data-content="<%= tooltip %>"
    >
      <%= title %>
      <%= sort_order_icon(sort_by, @sort_by, @sort_order) %>
    </th>
    """
  end

  def render(assigns) do
    ~L"""
    <thead>
      <tr>
        <th
          tabindex="0"
          style="cursor: pointer"
          phx-click="sort"
          phx-value-sort-by="title"
          scope="col"
          phx-keyup="sort">
          <%= case @selected do
            :by_page -> "Page Title"
            :by_activity -> "Activity Title"
            :by_objective -> "Objective"
            _ -> "Objective"
          end %>
          <%= sort_order_icon("title", @sort_by, @sort_order) %>
        </th>
        <%= th(assigns,
          "number_of_attempts",
          "Number of Attempts",
          "Number of total student submissions")
        %>
        <%= th(assigns,
          "relative_difficulty",
          "Relative Difficulty",
          "(Number of hints requested + Number of incorrect submissions) / Total submissions")
        %>
        <%= th(assigns,
          "eventually_correct",
          "Eventually Correct",
          "Ratio of the time a student with at least one submission eventually gets the correct answer")
        %>
        <%= th(assigns,
          "first_try_correct",
          "First Try Correct",
          "Ratio of the time a student gets the correct answer on their first submission")
        %>
      </tr>
    </thead>
    """
  end

  defp sort_order_icon(column, sort_by, :asc) when column == sort_by, do: "▲"
  defp sort_order_icon(column, sort_by, :desc) when column == sort_by, do: "▼"
  defp sort_order_icon(_, _, _), do: ""
end
