defmodule OliWeb.Insights.TableRow do
  use Phoenix.LiveComponent
  alias OliWeb.Common.Links
  alias OliWeb.Insights

  def render(assigns) do
    # slice is a page, activity, or objective revision
    %{
      slice: slice,
      number_of_attempts: number_of_attempts,
      relative_difficulty: relative_difficulty,
      eventually_correct: eventually_correct,
      first_try_correct: first_try_correct
    } = assigns.row

    ~L"""
    <tr class="<%= if Map.has_key?(assigns.row, :child_rows) do "table-light" else "" end %>">
      <th scope="row">
        <%= if Map.get(assigns.row, :is_child, false) do %>
          <span class="ml-3">&nbsp;</span>
        <% end %>
        <%= Links.resource_link(slice, assigns.parent_pages, assigns.project) %>
      </th>
      <%= if @selected == :by_page do %>
        <td>
          <%= if !is_nil(Map.get(@row, :activity)) do @row.activity.title end %>
        </td>
      <% end %>
      <td><%= if number_of_attempts == nil do "No attempts" else number_of_attempts end %></td>
      <td><%= Insights.truncate(relative_difficulty) %></td>
      <td><%= Insights.format_percent(eventually_correct) %></td>
      <td><%= Insights.format_percent(first_try_correct) %></td>
    </tr>
    """
  end
end
