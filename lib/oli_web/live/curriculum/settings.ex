defmodule OliWeb.Curriculum.Settings do

  @moduledoc """
  Selected curriculum item settings editing component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML
  alias Oli.Resources.ScoringStrategy

  defp selected_attr(item, item), do: "selected=\"selected\""
  defp selected_attr(_, _), do: ""

  defp disabled_attr(false), do: "disabled"
  defp disabled_attr(_), do: ""

  def render(assigns) do

    ~L"""
    <%= _ = form_for @changeset, "#", [phx_change: :save] %>

      <div class="mb-1"><p>Grading Type:</p></div>

      <select class="custom-select mb-1" name="graded">
        <option <%= selected_attr(@page.graded, true) %> value="true">Graded Assessment</option>
        <option <%= selected_attr(@page.graded, false) %> value="false">Ungraded Practice Page</option>
      </select>
      <p class="text-muted">
        <%= case @page.graded do
          true -> "Graded assessments report a grade to the gradebook."
          false -> "Practice pages do not report a grade to the gradebook."
        end %>
      </p>

      <div class="mt-4 mb-1"><p>Number of Attempts:</p></div>
      <select <%= disabled_attr(@page.graded) %> class="custom-select mb-1" name="max_attempts">
        <%= for c <- 1..10 do %>
        <option value="<%= c %>" <%= selected_attr(@page.max_attempts, c) %>>
          <%= c %>
        </option>
        <% end %>
        <option <%= selected_attr(@page.max_attempts, 0) %> value="0">Unlimited</option>
      </select>
      <p class="text-muted">
        <%= case @page.graded do
          true -> "Graded assessments allow a configurable number of attempts."
          false -> "Practice pages offer unlimited attempts."
        end %>
      </p>

      <%= case @page.graded do %>
        <% true -> %>
          <div class="mt-4 mb-1"><p>Scoring Strategy</p></div>
          <select <%= disabled_attr(@page.graded) %> class="custom-select mb-1" name="scoring_strategy_id">
            <%= for %{id: id, type: type} <- ScoringStrategy.get_types() do %>
              <option value="<%= id %>" <%= selected_attr(@page.scoring_strategy_id, id) %>>
                <%= Oli.Utils.snake_case_to_friendly(type) %>
              </option>
            <% end %>
          </select>
          <p class="text-muted">
            The scoring strategy determines how to calculate the final gradebook score across
            all attempts.
          </p>
        <% false -> %>
      <% end %>

    </form>

    <hr/>

    <div class="mt-4">
      <button type="button" class="btn btn-outline-danger" data-toggle="modal" data-target="#exampleModalCenter">
        Delete this Curriculum Item
      </button>
    </div>

    <div class="modal fade" id="exampleModalCenter" tabindex="-1" role="dialog" aria-labelledby="exampleModalCenterTitle" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLongTitle">Delete Curriculum Item</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            <p>Are you sure you want to delete this curriculum item?</p>
            <p>This is an operation that cannot be undone.</p>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-danger" data-dismiss="modal" phx-click="delete">Delete</button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
