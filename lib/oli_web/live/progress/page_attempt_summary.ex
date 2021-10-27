defmodule OliWeb.Progress.PageAttemptSummary do
  use Surface.Component

  prop attempt, :struct, required: true

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
      <p class="mb-1">Started: {with_time(@attempt.inserted_at)}</p>
      <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, DateTime.utc_now())}.</small>
    </li>
    """
  end

  def render_evaluated(assigns) do
    ~F"""
    <li class="list-group-item list-group-action flex-column align-items-start">
      <div class="d-flex w-100 justify-content-between">
        <h5 class="mb-1">Attempt {@attempt.attempt_number}</h5>
        <span>{@attempt.score} / {@attempt.out_of}</span>
      </div>
      <p class="mb-1 text-muted">Submitted: {with_time(@attempt.date_evaluated)} ({relative(@attempt.date_evaluated)})</p>
      <small class="text-muted">Time elapsed: {duration(@attempt.inserted_at, @attempt.date_evaluated)}.</small>
    </li>
    """
  end

  defp relative(d) do
    Timex.format!(d, "{relative}", :relative)
  end

  defp with_time(d) do
    Timex.format!(d, "%Y-%m-%d %H:%M:%S", :strftime)
  end

  defp duration(from, to) do
    Timex.diff(from, to, :milliseconds)
    |> Timex.Duration.from_milliseconds()
    |> Timex.format_duration(:humanized)
  end
end
