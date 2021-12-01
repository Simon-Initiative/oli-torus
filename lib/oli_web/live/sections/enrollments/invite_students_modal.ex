defmodule OliWeb.Sections.InviteStudentsModal do
  use OliWeb, :live_component
  use Phoenix.HTML
  import Phoenix.LiveView.Helpers

  def render(assigns) do
    ~L"""
    <div class="modal fade show" id="delete" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Invite students to <%= @section.title %></h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
          <%= if @show_invite_settings do %>

            <p>Invite link settings</p>

            <%= #How do you use a form in liveview?? this doesnt work %>
            <%= form_for @section_invite, :create, [phx_change: :update_section_invite, phx_submit: :generate_section_invite], fn f -> %>
              <%= label f, :date_expires, "Expire after" %>
              <%= multiple_select f, :date_expires, @date_expires_options, class: "form-control w-100" %>
              <%= submit "Generate Link" %>
            <% end %>

          <% else %>

            <label for="invite-link">Send an invite link to students</label>
            <div class="input-group mb-3">
              <input readonly type="text" id="invite-link" class="form-control" placeholder="Section Invite Link" aria-label="Section Invite Link" value="<%= Routes.delivery_url(OliWeb.Endpoint, :enroll_independent,@section_invite.slug) %>">
              <div class="input-group-append">
                <button id="copy-invite-link-button" class="btn btn-outline-secondary" data-clipboard-target="#invite-link" phx-hook="CopyListener">
                  <i class="lar la-clipboard"></i> Copy
                </button>
              </div>
            </div>
            <div>
              <small>
                Your invite link expires in 7 days. <button phx-click="open_link_settings" class="btn btn-link">Edit invite link.</button>
              </small>
            </div>

          <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
