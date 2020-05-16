defmodule OliWeb.Insights.TableRow do
  use Phoenix.LiveComponent

  def render(assigns) do
    # slice is a page, activity, or objective
    %{
      slice: slice,
      number_of_attempts: number_of_attempts,
      relative_difficulty: relative_difficulty,
      eventually_correct: eventually_correct,
      first_try_correct: first_try_correct
    } = assigns.row

    ~L"""
    <tr>
      <th scope="row"><a href="#"><%= slice.title %></a></th>
      <td><%= if number_of_attempts == nil do "No attempts" else number_of_attempts end %></td>
      <td><%= relative_difficulty %></td>
      <td><%= eventually_correct %></td>
      <td><%= first_try_correct %></td>
    </tr>
    """
  end
end
