defmodule OliWeb.Sections.Invites.Invitation do
  use OliWeb, :surface_component
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils

  prop invitation, :struct, required: true
  prop delete, :event, required: true
  prop context, :struct, required: true

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
              <i class="far fa-clipboard"></i> Copy
            </button>
          </div>
        </div>
        <div>
          <button class="btn btn-link" :on-click={@delete} phx-value-id={@invitation.id}><i class="fas fa-trash-alt fa-lg"></i></button>
        </div>
      </div>
      {#if active}
        <p class="mb-1">Expires: {Utils.render_precise_date(@invitation, :date_expires, @context)}</p>
        <small class="text-muted">Time remaining: {duration(@invitation.date_expires, DateTime.utc_now())}.</small>
      {#else}
        <p class="mb-1">Expired: {Utils.render_precise_date(@invitation, :date_expires, @context)}</p>
      {/if}
    </li>
    """
  end
end
