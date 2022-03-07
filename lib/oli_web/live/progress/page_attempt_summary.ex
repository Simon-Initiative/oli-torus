defmodule OliWeb.Progress.PageAttemptSummary do
  use OliWeb, :surface_component
  alias OliWeb.Router.Helpers, as: Routes
  prop attempt, :struct, required: true
  prop section, :struct, required: true

  @spec render(
          atom
          | %{
              :attempt => atom | %{:date_evaluated => any, optional(any) => any},
              optional(any) => any
            }
        ) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    case assigns.attempt.date_evaluated do
      nil -> render_in_progress(assigns)
      _ -> render_evaluated(assigns)
    end
  end

  def render_in_progress(assigns) do
    ~F"""
    <li class="list-group-item list-group-action flex-column align-items-start">
      <div class="d-flex w-100 justify-content-between">
        <h5 class="mb-1">Attempt {@attempt.attempt_number}</h5>
        <span>Not Submitted Yet</span>
      </div>
      <p class="mb-1">Started: {date(@attempt.inserted_at)}</p>
      <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, DateTime.utc_now())}.</small>
    </li>
    """
  end

  def render_evaluated(assigns) do
    ~F"""
    <li class="list-group-item list-group-action flex-column align-items-start">
      <a href={Routes.instructor_review_path(OliWeb.Endpoint, :review_attempt, @section.slug, @attempt.attempt_guid)}>
        <div class="d-flex w-100 justify-content-between">
          <h5 class="mb-1">Attempt {@attempt.attempt_number}</h5>
          <span>{@attempt.score} / {@attempt.out_of}</span>
        </div>
        <p class="mb-1 text-muted">Submitted: {date(@attempt.date_evaluated)} ({date(@attempt.date_evaluated, precision: :relative)})</p>
        <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, @attempt.date_evaluated)}.</small>
      </a>
    </li>
    """
  end
end
