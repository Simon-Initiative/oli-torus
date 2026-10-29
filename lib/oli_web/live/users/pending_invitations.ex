defmodule OliWeb.Users.PendingInvitations do
  use OliWeb, :html

  alias OliWeb.Components.Modal
  alias OliWeb.Common.SortableTable.StripedTable
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Phoenix.LiveView.JS

  attr :invitations, :list, required: true
  attr :id, :string, default: "pending_invitations"
  attr :decline_invitation_id, :integer, default: nil

  def render(assigns) do
    invitations =
      Enum.map(assigns.invitations, fn invitation ->
        Map.put(invitation, :pending_invitation_id, "pending-invitation-#{invitation.id}")
      end)

    {:ok, table_model} =
      SortableTableModel.new(
        rows: invitations,
        column_specs: column_specs(),
        event_suffix: "",
        id_field: :pending_invitation_id
      )

    assigns = Phoenix.Component.assign(assigns, :table_model, table_model)

    ~H"""
    <div :if={@invitations != []} id={@id} class="w-full overflow-x-auto">
      <StripedTable.render
        model={@table_model}
        sort=""
        additional_table_class="border-collapse text-xs"
      >
        <:caption>
          <caption class="border border-b-0 border-Border-border-default p-2 text-left font-semibold">
            Pending Invitations
          </caption>
        </:caption>
      </StripedTable.render>

      <Modal.modal
        :if={@decline_invitation_id}
        id="decline_invitation_modal"
        show={true}
        wrapper_class="w-full max-w-md p-4 sm:p-6 lg:py-8"
        on_cancel={JS.push("cancel_decline_invitation")}
        on_confirm={
          JS.push("decline_invitation", value: %{id: @decline_invitation_id})
          |> Modal.hide_modal("decline_invitation_modal")
        }
      >
        <:title>Decline invitation</:title>
        Are you sure you want to decline this invitation?
        <:cancel>Cancel</:cancel>
        <:confirm>Decline</:confirm>
      </Modal.modal>
    </div>
    """
  end

  defp column_specs do
    [
      %ColumnSpec{
        name: :title,
        label: "Invitation",
        sortable: false,
        th_class: "sr-only",
        td_class: "border-t",
        render_fn: &render_invitation/3
      },
      %ColumnSpec{
        name: :actions,
        label: "Actions",
        sortable: false,
        th_class: "sr-only",
        td_class: "border-t text-right",
        render_fn: &render_actions/3
      }
    ]
  end

  defp render_invitation(assigns, invitation, _column_spec) do
    assigns = Map.put(assigns, :invitation, invitation)

    ~H"""
    <.link navigate={@invitation.path} class="font-semibold text-Text-text-link">
      {@invitation.title}
    </.link>
    """
  end

  defp render_actions(assigns, invitation, _column_spec) do
    assigns = Map.put(assigns, :invitation, invitation)

    ~H"""
    <.button
      variant={:primary}
      size={:xs}
      phx-click="accept_invitation"
      phx-value-id={@invitation.id}
    >
      Accept
    </.button>
    <.button
      variant={:outline}
      size={:xs}
      class="ml-2 !border-Border-border-danger !text-Specially-Tokens-Text-text-button-pill-muted"
      phx-click="show_decline_invitation_modal"
      phx-value-id={@invitation.id}
    >
      Decline
    </.button>
    """
  end
end
