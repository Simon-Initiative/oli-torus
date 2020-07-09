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
      first_try_correct: first_try_correct
    } = assigns.row

    ~L"""
    <tr>
      <th scope="row">
        <%= Links.resource_link(slice, assigns.parent_pages, assigns.project) %>
      </th>
      <%= if !is_nil(Map.get(@row, :activity)) do %>
        <td><%= @row.activity.title %></td>
      <% end %>
      <td><%= if number_of_attempts == nil do "No attempts" else number_of_attempts end %></td>
      <td><%= relative_difficulty %></td>
      <td><%= format_percent(eventually_correct) %></td>
      <td><%= format_percent(first_try_correct) %></td>
    </tr>
    """
  end

  defp format_percent(float_or_nil) when is_nil(float_or_nil), do: nil
  defp format_percent(float_or_nil) when is_float(float_or_nil), do: "#{round(100 * float_or_nil)}%"

  # TODO: Link activity to resource
  defp link_url(slice) do
    import Oli.Resources.ResourceType, only: [get_id_by_type: 1]
    cond do
      slice.resource_type.id == get_id_by_type("objective") -> "objectives"
      slice.resource_type.id == get_id_by_type("page") -> "resource/#{slice.slug}"
      slice.resource_type.id == get_id_by_type("activity") -> ""
    end
  end

end
