defmodule OliWeb.ManualGrading.PartScoring do
  use OliWeb, :html

  attr :part_attempt, :any, required: true
  attr :part_scoring, :map, required: true
  attr :feedback_changed, :any, required: true
  attr :score_changed, :any, required: true

  def render(%{part_attempt: %{lifecycle_state: :evaluated}} = assigns) do
    ~H"""
    <form>
      <div class="form-row">
        <div class="col-span-11">
          {feedback(assigns)}
        </div>
        <div class="col">
          <div class="input-group mb-3">
            <div class="input-group-prepend">
              <span class="input-group-text">Score</span>
            </div>
            <input type="text" disabled class="form-control" value={@part_attempt.score} />
          </div>

          <div class="input-group mb-3">
            <div class="input-group-prepend">
              <span class="input-group-text">Out Of</span>
            </div>
            <input type="text" disabled class="form-control" value={@part_attempt.out_of} />
          </div>
        </div>
      </div>
    </form>
    """
  end

  def render(assigns) do
    ~H"""
    <form>
      <div class="form-row">
        <div class="col-span-10">
          <textarea
            id={"feedback_" <> @part_attempt.attempt_guid}
            phx-hook="TextInputListener"
            phx-value-change={@feedback_changed}
            class="form-control my-3 w-full"
            placeholder="Enter feedback for the student..."
            autocomplete="on"
            wrap="soft"
            maxlength="2000"
          ><%= @part_scoring.feedback %></textarea>
        </div>
        <div class="col">
          <div class="input-group mb-3">
            <div class="input-group-prepend">
              <span class="input-group-text p-1 mr-2 whitespace-nowrap align-middle">Score</span>
            </div>
            <input
              id={"score_" <> @part_attempt.attempt_guid}
              phx-hook="TextInputListener"
              phx-value-change={@score_changed}
              type="number"
              class="form-control"
              step="1"
              min="0"
              max={@part_scoring.out_of}
              value={@part_scoring.score}
            />
          </div>

          <div class="input-group mb-3">
            <div class="input-group-prepend">
              <span class="input-group-text p-1 mr-2 whitespace-nowrap align-middle">Out Of</span>
            </div>
            <input type="text" disabled class="form-control" value={@part_scoring.out_of} />
          </div>

          <div class="btn-group" role="group" aria-label="Scoring shortcut group">
            <button
              type="button"
              class="btn btn-sm btn-secondary"
              phx-click={@score_changed}
              phx-value-id={"score_" <> @part_attempt.attempt_guid}
              phx-value-score={0}
            >
              0%
            </button>
            <button
              type="button"
              class="btn btn-sm btn-secondary"
              phx-click={@score_changed}
              phx-value-id={"score_" <> @part_attempt.attempt_guid}
              phx-value-score={@part_scoring.out_of / 2}
            >
              50%
            </button>
            <button
              type="button"
              class="btn btn-sm btn-secondary"
              phx-click={@score_changed}
              phx-value-id={"score_" <> @part_attempt.attempt_guid}
              phx-value-score={@part_scoring.out_of}
            >
              100%
            </button>
          </div>
        </div>
      </div>
    </form>
    """
  end

  defp feedback(%{part_attempt: %{grading_approach: :automatic}} = assigns) do
    ~H"""
    <p>This part was automatically graded by the system</p>
    """
  end

  defp feedback(assigns) do
    ~H"""
    <textarea
      id={@part_attempt.attempt_guid}
      disabled
      class="form-control"
      wrap="soft"
      maxlength="2000"
    ><%= @part_scoring.feedback %></textarea>
    """
  end
end
