defmodule OliWeb.Insights.TableRow do
  use Phoenix.LiveComponent
  alias OliWeb.Common.Links
  alias OliWeb.Insights

  def render(assigns) do
    # slice is a page, activity, or objective revision
    assigns =
      assigns
      |> assign(:row, assigns.row)
      |> assign(:activity, Map.get(assigns.row, :activity))

    ~H"""
    <tr class={"#{if Map.has_key?(assigns.row, :child_rows) do "table-light" else "" end}"}>
      <th scope="row">
        <%= if Map.get(assigns.row, :is_child, false) do %>
          <span class="ml-3">&nbsp;</span>
        <% end %>
        <%= Links.resource_link(@row.slice, assigns.parent_pages, assigns.project) %>
      </th>
      <%= if @selected == :by_page do %>
        <td>
          <%= if !is_nil(@activity) do
            @row.activity.title
          end %>
        </td>
      <% end %>
      <td>
        <%= if @row.number_of_attempts == nil do
          "No attempts"
        else
          @row.number_of_attempts
        end %>
      </td>
      <td><%= Insights.truncate(@row.relative_difficulty) %></td>
      <td><%= Insights.format_percent(@row.eventually_correct) %></td>
      <td><%= Insights.format_percent(@row.first_try_correct) %></td>
    </tr>
    """
  end
end
