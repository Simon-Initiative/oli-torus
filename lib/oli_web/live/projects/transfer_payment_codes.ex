defmodule OliWeb.Projects.TransferPaymentCodes do
  use Phoenix.LiveComponent
  alias Oli.Auditing.Context

  attr :project, :map, required: true
  attr :author, :map, required: true, doc: "the author changing the setting"

  attr :revert_count, :integer,
    default: 0,
    doc: "changes after a failed save, so the checkbox renders again from the saved state"

  def render(assigns) do
    ~H"""
    <div class="flex items-center h-full">
      <form phx-change="set_allow_transfer" phx-target={@myself}>
        <%!-- A new id after a failed save renders the checkbox again from the saved state --%>
        <div class="form-check" id={"transfer_payment_codes_wrapper-#{@revert_count}"}>
          <label class="form-check-label">
            <input
              id="transfer_payment_codes"
              name="transfer_payment_codes"
              type="checkbox"
              checked={@project.allow_transfer_payment_codes}
            />
            <span>
              Allow transfer of payment codes
            </span>
          </label>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("set_allow_transfer", _params, socket) do
    %{project: project, author: author} = socket.assigns

    case Oli.Authoring.Audited.update_project_settings(
           Context.for_actor(author, source: :ui),
           project.id,
           %{allow_transfer_payment_codes: !project.allow_transfer_payment_codes},
           [:allow_transfer_payment_codes]
         ) do
      {:ok, updated} ->
        {:noreply,
         assign(socket,
           project: %{
             project
             | allow_transfer_payment_codes: updated.allow_transfer_payment_codes
           }
         )}

      {:error, _reason} ->
        send(self(), {:flash_message, {:error, "The setting could not be saved."}})
        {:noreply, assign(socket, revert_count: Map.get(socket.assigns, :revert_count, 0) + 1)}
    end
  end
end
