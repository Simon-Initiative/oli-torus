defmodule OliWeb.Progress.PageAttemptSummary do
  use OliWeb, :surface_component
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils

  prop attempt, :struct, required: true
  prop section, :struct, required: true
  prop context, :struct, required: true

  @spec render(
          atom
          | %{
              :attempt => atom | %{:date_evaluated => any, optional(any) => any},
              optional(any) => any
            }
        ) :: Phoenix.LiveView.Rendered.t()
  def render(assigns), do: do_render(assigns)

  def do_render(%{attempt: %{lifecycle_state: :active}} = assigns) do
    ~F"""
    <div class="list-group-item list-group-action flex-column align-items-start">
      <a href={Routes.instructor_review_path(OliWeb.Endpoint, :review_attempt, @section.slug, @attempt.attempt_guid)} class="block">
        <div class="d-flex w-100 justify-content-between">
          <h5 class="mb-1">Attempt {@attempt.attempt_number}</h5>
          <span>Not Submitted Yet</span>
        </div>
        <p class="mb-1">Started: {Utils.render_date(@attempt, :inserted_at, @context)}</p>
        <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, DateTime.utc_now())}.</small>
      </a>
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
        <p class="mb-1 text-muted">Submitted: {Utils.render_date(@attempt, :date_evaluated, @context)} ({Utils.render_relative_date(@attempt, :date_evaluated, @context)})</p>
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
        <p class="mb-1 text-muted">Submitted: {Utils.render_date(@attempt, :date_submitted, @context)} ({Utils.render_relative_date(@attempt, :date_submitted, @context)})</p>
        <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, @attempt.date_submitted)}.</small>
      </a>
    </div>
    """
  end
end
