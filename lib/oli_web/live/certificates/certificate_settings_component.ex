defmodule OliWeb.Certificates.CertificateSettingsComponent do
  use OliWeb, :live_component

  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(changeset: Section.changeset(assigns.product))}
  end

  def handle_event("toggle_certificate", params, socket) do
    certificate_enabled = params["certificate_enabled"] == "on"

    case Sections.update_section(socket.assigns.product, %{
           certificate_enabled: certificate_enabled
         }) do
      {:ok, product} ->
        {:noreply, assign(socket, product: product, changeset: Section.changeset(product))}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex-col justify-start items-start gap-[30px] inline-flex">
      <div role="title" class="self-stretch text-2xl font-normal">
        Certificate Settings
      </div>
      <.form
        for={@changeset}
        phx-target={@myself}
        phx-change="toggle_certificate"
        class="self-stretch justify-start items-center gap-3 inline-flex"
      >
        <input
          type="checkbox"
          class="form-check-input w-5 h-5 p-0.5"
          id="enable_certificates_checkbox"
          name="certificate_enabled"
          checked={Ecto.Changeset.get_field(@changeset, :certificate_enabled)}
        />
        <div class="grow shrink basis-0 text-base font-medium">
          Enable certificate capabilities for this product
        </div>
      </.form>
    </div>
    """
  end
end
