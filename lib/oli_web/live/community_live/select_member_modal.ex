defmodule OliWeb.CommunityLive.SelectMemberModal do
  use OliWeb, :html

  attr :id, :string, required: true
  attr :members, :list, required: true
  attr :select, :string, required: true

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={@id}
      style="display: block"
      tabindex="-1"
      role="dialog"
      aria-labelledby="delete-modal"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Select user</h5>
            <button type="button" class="close" data-bs-dismiss="modal" aria-label="Close">
              <i class="fa-solid fa-xmark fa-xl"></i>
            </button>
          </div>
          <div class="modal-body">
            <div class="mb-3">
              There is more than one user associated to that email, please select the one you want to add:
            </div>

            <div class="p-3">
              <div
                :for={member <- @members}
                class="d-flex justify-content-between align-items-center mb-3"
              >
                <div class="d-flex flex-column">
                  <div>{member.email} - {member.name}</div>
                  <div class="small text-muted">Sub: {member.sub}</div>
                </div>

                <button class="btn btn-link" phx-click={@select} phx-value-collaborator-id={member.id}>
                  Select
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
