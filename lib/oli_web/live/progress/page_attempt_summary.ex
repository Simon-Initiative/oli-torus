defmodule OliWeb.Progress.PageAttemptSummary do
  use OliWeb, :surface_component
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils

  prop(attempt, :struct, required: true)
  prop(section, :struct, required: true)
  prop(ctx, :struct, required: true)
  prop(revision, :struct, required: true)

  @spec render(
          atom
          | %{
              :attempt => atom | %{:date_evaluated => any, optional(any) => any},
              optional(any) => any
            }
        ) :: Phoenix.LiveView.Rendered.t()
  def render(assigns), do: do_render(assigns)

  def do_render(
        %{revision: %{graded: graded}, attempt: %{attempt_guid: guid, lifecycle_state: :active}} =
          assigns
      ) do
    ~F"""
    <div class="list-group-item list-group-action flex-column align-items-start">
      <a href={Routes.instructor_review_path(OliWeb.Endpoint, :review_attempt, @section.slug, @attempt.attempt_guid)} class="block">
        <div class="d-flex w-100 justify-content-between">
          <h5 class="mb-1">Attempt {@attempt.attempt_number}</h5>
          <span>Not Submitted Yet</span>
        </div>
        <p class="mb-1">Started: {Utils.render_date(@attempt, :inserted_at, @ctx)}</p>
        <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, DateTime.utc_now())}.</small>
      </a>
      {#if graded}
        <button class="btn btn-danger btn-sm" phx-click="submit_attempt" phx-value-guid={guid}>Submit Attempt on Behalf of Student</button>
      {/if}
    </div>
    """
  end

  def do_render(%{attempt: %{lifecycle_state: :evaluated}} = assigns) do
    ~F"""
    <div class="list-group-item list-group-action flex-column align-items-start">
      <a href={Routes.instructor_review_path(OliWeb.Endpoint, :review_attempt, @section.slug, @attempt.attempt_guid)} class="block">
        <div class="d-flex w-100 justify-content-between">
          <h5 class="mb-1">Attempt {@attempt.attempt_number}</h5>
          <span>{Utils.format_score(@attempt.score)} / {@attempt.out_of}</span>
        </div>
        <div class="d-flex flex-row">
          {#if @attempt.was_late}
            <.badge variant={:danger}>LATE</.badge>
          {/if}
          <p class="mb-1 text-muted">Submitted: {Utils.render_date(@attempt, :date_evaluated, @ctx)} ({Utils.render_relative_date(@attempt, :date_evaluated, @ctx)})</p>
        </div>

        <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, @attempt.date_evaluated)}.</small>
        </a>
    </div>
    """
  end

  def do_render(%{attempt: %{lifecycle_state: :submitted}} = assigns) do
    ~F"""
    <div class="list-group-item list-group-action flex-column align-items-start">
      <a href={Routes.instructor_review_path(OliWeb.Endpoint, :review_attempt, @section.slug, @attempt.attempt_guid)} class="block">
        <div class="d-flex w-100 justify-content-between">
          <h5 class="mb-1">Attempt {@attempt.attempt_number}</h5>
          <span>Submitted</span>
        </div>
        <p class="mb-1 text-muted">Submitted: {Utils.render_date(@attempt, :date_submitted, @ctx)} ({Utils.render_relative_date(@attempt, :date_submitted, @ctx)})</p>
        <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, @attempt.date_submitted)}.</small>
      </a>
    </div>
    """
  end
end
