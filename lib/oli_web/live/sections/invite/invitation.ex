defmodule OliWeb.Sections.Invites.Invitation do
  use Surface.Component
  alias OliWeb.Router.Helpers, as: Routes

  prop invitation, :struct, required: true
  prop delete, :event, required: true

  def render(assigns) do
    case duration(assigns.invitation.date_expires, DateTime.utc_now()) <= 0 do
      true -> render_expired(assigns)
      _ -> render_active(assigns)
    end
  end

  def render_active(assigns) do
    ~F"""
    <li class="list-group-item list-group-action flex-column align-items-start">
      <div class="d-flex w-100 justify-content-between">
        <a href={Routes.delivery_url(OliWeb.Endpoint, :enroll_independent, @invitation.slug)}>
          {Routes.delivery_url(OliWeb.Endpoint, :enroll_independent, @invitation.slug)}
        </a>
        <button class="btn btn-warning btn-sm" :on-click={@delete} phx-value-id={@invitation.id}>Remove</button>
      </div>
      <p class="mb-1">Expires: {with_time(@invitation.date_expires)}</p>
      <small class="text-muted">Time remaining: {duration(@invitation.date_expires, DateTime.utc_now())}.</small>
    </li>
    """
  end

  def render_expired(assigns) do
    ~F"""
    <li class="list-group-item list-group-action flex-column align-items-start">
      <div class="d-flex w-100 justify-content-between">
        <a href={Routes.delivery_url(OliWeb.Endpoint, :enroll_independent, @invitation.slug)}>
          {Routes.delivery_url(OliWeb.Endpoint, :enroll_independent, @invitation.slug)}
        </a>
      </div>
      <p class="mb-1">Expired: {with_time(@invitation.date_expires)}</p>
    </li>
    """
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
