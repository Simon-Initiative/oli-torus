defmodule OliWeb.CommunityLive.SelectMemberModal do
  use Surface.Component

  prop id, :string, required: true
  prop members, :list, required: true
  prop select, :event, required: true

  def render(assigns) do
    ~F"""
    <div class="modal fade show" id={@id} style="display: block" tabindex="-1" role="dialog" aria-labelledby="delete-modal" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Select user</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            <div class="mb-3">There is more than one user associated to that email, please select the one you want to add:</div>

            <div class="p-3">
              {#for member <- @members}
                <div class="d-flex justify-content-between align-items-center mb-3">
                  <div class="d-flex flex-column">
                    <div>{member.email} - {member.name}</div>
                    <div class="small text-muted">Sub: {member.sub}</div>
                  </div>

                  <button class="btn btn-link" :on-click={@select} phx-value-collaborator-id={member.id}>Select</button>
                </div>
              {/for}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
