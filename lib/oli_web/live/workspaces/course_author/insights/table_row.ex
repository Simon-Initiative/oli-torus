defmodule OliWeb.Workspaces.CourseAuthor.TableRow do
  use OliWeb, :html
  alias OliWeb.Common.Links
  alias OliWeb.Workspaces.CourseAuthor.InsightsLive

  attr :row, :map
  attr :parent_pages, :list
  attr :project, :any
  attr :selected, :atom

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
        <%= if @row.number_of_attempts == nil, do: "No attempts", else: @row.number_of_attempts %>
      </td>
      <td><%= InsightsLive.truncate(@row.relative_difficulty) %></td>
      <td><%= InsightsLive.format_percent(@row.eventually_correct) %></td>
      <td><%= InsightsLive.format_percent(@row.first_try_correct) %></td>
    </tr>
    """
  end
end
