defmodule OliWeb.Objectives.CreateGroupModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.ErrorHelpers

  alias OliWeb.Objectives.Attachments

  def render(assigns) do
    ~L"""
    <div class="modal fade show" id="<%= @id %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <%= form_for @changeset, "#",
            [id: "new-group-form",
            as: :group_params,
            phx_change: "validate-create",
            phx_submit: "create"],
            fn f -> %>
              <div class="modal-header">
                <h5 class="modal-title">Create Group</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                  <span aria-hidden="true">&times;</span>
                </button>
              </div>
              <div class="modal-body">
                <p>Please enter a name for the alternatives group</p>

                <div class="form-group">
                  <%= text_input f,
                    :name,
                    class: "form-control my-2" <> error_class(f, :name, "is-invalid"),
                    placeholder: "Name",
                    phx_hook: "InputAutoSelect",
                    required: true %>
                </div>

              </div>
              <div class="modal-footer">
                <button type="button" class="btn btn-link" data-dismiss="modal">Cancel</button>
                <%= submit "Create", class: "btn btn-primary" %>
              </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
