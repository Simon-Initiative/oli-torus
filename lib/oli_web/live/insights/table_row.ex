defmodule OliWeb.Insights.TableRow do
  use Phoenix.LiveComponent
  alias OliWeb.Common.Links

  def render(assigns) do
    # slice is a page, activity, or objective revision
    %{
      slice: slice,
      number_of_attempts: number_of_attempts,
      relative_difficulty: relative_difficulty,
      eventually_correct: eventually_correct,
      first_try_correct: first_try_correct,
    } = assigns.row

    ~L"""
    <tr>
      <th scope="row">
        <%= Links.resource_link(slice, assigns.parent_pages, assigns.project) %>
      </th>
      <%= if @selected == :by_objective || @selected == :by_page do %>
        <td>
          <%= if !is_nil(Map.get(@row, :activity)) do @row.activity.title end %>
        </td>
      <% end %>
      <td><%= if number_of_attempts == nil do "No attempts" else number_of_attempts end %></td>
      <td><%= truncate(relative_difficulty) %></td>
      <td><%= format_percent(eventually_correct) %></td>
      <td><%= format_percent(first_try_correct) %></td>
    </tr>
    """
  end

  defp truncate(float_or_nil) when is_nil(float_or_nil), do: nil
  defp truncate(float_or_nil) when is_float(float_or_nil), do: Float.round(float_or_nil, 2)

  defp format_percent(float_or_nil) when is_nil(float_or_nil), do: nil

  defp format_percent(float_or_nil) when is_float(float_or_nil),
    do: "#{round(100 * float_or_nil)}%"
end
