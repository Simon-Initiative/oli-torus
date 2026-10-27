defmodule OliWeb.Users.PendingInvitations do
  use OliWeb, :html

  attr :invitations, :list, required: true
  attr :id, :string, default: "pending_invitations"

  def render(assigns) do
    ~H"""
    <div :if={@invitations != []} id={@id} class="w-full overflow-x-auto">
      <table class="w-full border-collapse border border-Border-border-default text-xs">
        <caption class="border border-b-0 border-Border-border-default p-2 text-left font-semibold">
          Pending Invitations
        </caption>
        <thead class="sr-only">
          <tr>
            <th scope="col">Invitation</th>
            <th scope="col">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={invitation <- @invitations}
            id={"pending-invitation-#{invitation.id}"}
            class="bg-Table-table-row-1"
          >
            <td class="border-t border-Border-border-default p-2">
              <.link
                navigate={invitation.path}
                class="font-semibold text-Text-text-link"
              >
                {invitation.title}
              </.link>
            </td>
            <td class="border-t border-Border-border-default p-2 text-right">
              <.button
                variant={:primary}
                size={:xs}
                phx-click="accept_invitation"
                phx-value-id={invitation.id}
              >
                Accept
              </.button>
              <.button
                variant={:outline}
                size={:xs}
                class="ml-2 !border-Border-border-danger !text-Specially-Tokens-Text-text-button-pill-muted"
                phx-click="decline_invitation"
                phx-value-id={invitation.id}
              >
                Decline
              </.button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
