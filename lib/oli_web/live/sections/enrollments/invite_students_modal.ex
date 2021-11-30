defmodule OliWeb.Sections.InviteStudentsModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias Oli.Delivery.Sections.Section

  def render(%{section: %Section{} = section, emails: emails} = assigns) do
    ~L"""
    <style>
      # .email-invite-list {
      #   max-height: 300px;
      #   overflow: scroll;
      # }
    </style>
    <div class="modal fade show" id="delete" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Invite students to <%= section.title %></h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <div class="form-group">
                <form phx-change="InviteStudentsModal.addEmails">
                  <label for="addEmailsTextarea">Add students by email</label>
                  <textarea name="emails" class="form-control" id="addEmailsTextarea" rows="3">hey</textarea>
                </form>
                <button type="button" class="btn btn-primary" phx-click="InviteStudentsModal.sendEmail">
                  Send email invitations
                </button>
              </div>
              <ul class="list-group email-invite-list">
                <% IO.inspect(emails, label: "Emails in modal") %>
                <%= for email <- emails do %>
                  <li class="list-group-item">
                    <span><%=email%></span>
                    <button class="btn btn-outline" phx-click="InviteStudentsModal.removeEmail" phx-value-email="<%=email%>" type="button" class="close" aria-label="Remove">
                      <span aria-hidden="true">&times;</span>
                    </button>
                  </li>
                <% end %>
              </ul>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="InviteStudentsModal.hide">Cancel</button>
              <button
                phx-click="InviteStudentsModal.remove"
                phx-key="enter"
                phx-value-uuid="<%= 1 %>"
                class="btn btn-danger">
                Remove
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
