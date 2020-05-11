defmodule OliWeb.Insights.TableRow do
  use Phoenix.LiveComponent

  def render(assigns) do
    # content is a page, activity, or skill
    %{
      content: content,
      number_of_attempts: number_of_attempts,
      relative_difficulty: relative_difficulty,
      eventually_correct: eventually_correct,
      first_try_correct: first_try_correct
    } = assigns.row

    ~L"""
    <tr>
      <th scope="row"><a href="#"><%= content %></a></th>
      <td><%= number_of_attempts %></td>
      <td><%= relative_difficulty %></td>
      <td><%= eventually_correct %></td>
      <td><%= first_try_correct %></td>
    </tr>
    """
  end
end
