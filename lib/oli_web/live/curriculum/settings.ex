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
    <%= f = form_for @changeset, "#", [phx_submit: "save"] %>

      <div><small>Grading Type:</small></div>

      <%= hidden_input(f, :id, id: "id-#{@child.id}") %>

      <%= select(f, :graded, ["Graded Assessment": "true", "Ungraded Practice Page": "false"],
      id: "graded-#{@child.id}", class: "custom-select") %>
      <small class="text-muted">
        Graded assessments report a grade to the gradebook, while practice pages do not.
      </small>

      <div class="mt-4"><small>Number of Attempts:</small></div>
      <%= select(f, :max_attempts, 1..10, id: "attempts-#{@child.id}") %>
      <small class="text-muted">
        Graded assessments allow a configurable number of attempts, while practice pages
        offer unlimited attempts.
      </small>

      <div class="mt-4"><small>Scoring Strategy</small></div>
      <%= select(f, :scoring_strategy_id,
      Enum.map(ScoringStrategy.get_types(), & {"#{Oli.Utils.snake_case_to_friendly(&1[:type])}", &1[:id]}),
      id: "strategy-#{@child.id}") %>
      <small class="text-muted">
      The scoring strategy determines how to calculate the final gradebook score across
      all attempts.
      </small>

      <%= submit "Save" %>

    </form>

    <hr/>

    <div class="mt-4">
      <button type="button" class="btn btn-outline-danger" data-toggle="modal" data-target="#delete-<%= @child.slug %>">
        Delete this Curriculum Item
      </button>
    </div>

    <div class="modal fade" id="delete-<%= @child.slug %> " tabindex="-1" role="dialog" aria-labelledby="exampleModalCenterTitle" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Delete Curriculum Item</h5>
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
