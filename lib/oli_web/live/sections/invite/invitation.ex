defmodule OliWeb.Sections.Invites.Invitation do
  use Surface.Component
  alias OliWeb.Router.Helpers, as: Routes

  prop invitation, :struct, required: true
  prop delete, :event, required: true

  def render(assigns) do
    assigns
    |> do_render(Timex.diff(assigns.invitation.date_expires, DateTime.utc_now()) > 0)
  end

  def do_render(assigns, active) do
    ~F"""
    <li class="list-group-item list-group-action flex-column align-items-start">
      <div class="d-flex w-100 justify-content-between">
        <div class="input-group mb-3" style="max-width: 50%;">
          <input readonly type="text" id={"invite-link-#{@invitation.id}"} class="form-control" placeholder="Section Invite Link" aria-label="Section Invite Link" value={Routes.delivery_url(OliWeb.Endpoint, :enroll_independent, @invitation.slug)}>
          <div class="input-group-append">
            <button id="copy-invite-link-button" class="btn btn-outline-secondary" data-clipboard-target={"#invite-link-#{@invitation.id}"} phx-hook="CopyListener">
              <i class="lar la-clipboard"></i> Copy
            </button>
          </div>
        </div>
        <div>
          <button class="btn btn-link" :on-click={@delete} phx-value-id={@invitation.id}><i class="fas fa-trash-alt fa-lg"></i></button>
        </div>
      </div>
      {#if active}
        <p class="mb-1">Expires: {with_time(@invitation.date_expires)}</p>
        <small class="text-muted">Time remaining: {duration(@invitation.date_expires, DateTime.utc_now())}.</small>
      {#else}
        <p class="mb-1">Expired: {with_time(@invitation.date_expires)}</p>
      {/if}
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
