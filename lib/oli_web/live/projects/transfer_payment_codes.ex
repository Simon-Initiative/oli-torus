defmodule OliWeb.Projects.TransferPaymentCodes do
  use Phoenix.LiveComponent
  alias Oli.Authoring.Course

  attr :project, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="flex items-center h-full">
      <form phx-change="set_allow_transfer" phx-target={@myself}>
        <div class="form-check">
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
    project = socket.assigns.project

    {:ok, project} =
      Course.update_project(project, %{
        allow_transfer_payment_codes: !project.allow_transfer_payment_codes
      })

    {:noreply, assign(socket, project: project)}
  end
end
