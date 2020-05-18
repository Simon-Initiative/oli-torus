defmodule OliWeb.Insights.TableRow do
  use Phoenix.LiveComponent

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
        <a href=<%= link_url(slice) %>>
          <%= slice.title %>
        </a>
      </th>
      <td><%= if number_of_attempts == nil do "No attempts" else number_of_attempts end %></td>
      <td><%= relative_difficulty %></td>
      <td><%= format_percent(eventually_correct) %></td>
      <td><%= format_percent(first_try_correct) %></td>
    </tr>
    """
  end

  defp format_percent(float_or_nil) do
    if is_nil(float_or_nil)
    do float_or_nil
    else "#{100 * float_or_nil |> Decimal.from_float() |> Decimal.round(0) }%"
    end
  end

  defp link_url(slice) do
    objective_id = Oli.Resources.ResourceType.get_id_by_type("objective")
    activity_id = Oli.Resources.ResourceType.get_id_by_type("activity")
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    cond do
      slice.resource_type.id == objective_id -> "objectives"
      slice.resource_type.id == page_id -> "resource/#{slice.slug}"
      slice.resource_type.id == activity_id -> ""
    end
  end

end
