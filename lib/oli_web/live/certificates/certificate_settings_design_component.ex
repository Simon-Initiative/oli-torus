defmodule OliWeb.Certificates.CertificateSettingsDesignComponent do
  use OliWeb, :live_component

  alias Oli.Delivery.Sections.Certificate

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:logo, max_entries: 3, accept: ~w(.jpg .jpeg .png), max_file_size: 1_000_000)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(
       certificate_changeset: certificate_changeset(assigns.certificate),
       show_preview: false,
       preview_page: 0,
       certificate_html: {nil, nil}
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full flex-col">
      <div class="mb-14 text-base font-medium">
        Create and preview your certificate.
      </div>

      <.form
        :let={f}
        id="certificate-settings-design-form"
        for={@certificate_changeset}
        phx-change="validate"
        phx-drop-target={@uploads.logo.ref}
        phx-submit="save"
        phx-target={@myself}
        class="w-full justify-start items-center gap-3"
      >
        <div class="w-3/4 flex-col justify-start items-start gap-10 inline-flex">
          <!-- Title -->
          <div class="self-stretch flex-col justify-start items-start gap-3 flex">
            <div class="text-base font-bold">
              Course Title
            </div>
            <div class="w-full text-base">
              <.input
                type="text"
                field={f[:title]}
                value={@certificate_changeset.data.title}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
          </div>
          <!-- Subtitle -->
          <div class="self-stretch flex-col justify-start items-start gap-3 flex">
            <div class="text-base font-bold">
              Subtitle
            </div>
            <div class="text-base font-small">
              The description that appears under the name of the awardee
            </div>
            <div class="w-full text-base font-medium">
              <.input
                type="text"
                field={f[:description]}
                value={@certificate_changeset.data.description}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
          </div>
          <!-- Administrators -->
          <div class="self-stretch flex-col justify-start items-start gap-3 flex">
            <div class="text-base font-bold">
              Administrators
            </div>
            <div class="text-base font-small">
              Include up to three administrators on your certificate.
            </div>
            <div class="flex gap-3 items-center">
              <.input
                type="text"
                field={f[:admin_name1]}
                placeholder="Name 1"
                value={@certificate_changeset.data.admin_name1}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title1]}
                placeholder="Title 1"
                value={@certificate_changeset.data.admin_title1}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
            <div class="flex gap-3 items-center">
              <.input
                type="text"
                field={f[:admin_name2]}
                placeholder="Name 2"
                value={@certificate_changeset.data.admin_name2}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title2]}
                placeholder="Title 2"
                value={@certificate_changeset.data.admin_title2}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
            <div class="flex gap-3 items-center">
              <.input
                type="text"
                field={f[:admin_name3]}
                placeholder="Name 3"
                value={@certificate_changeset.data.admin_name3}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title3]}
                placeholder="Title 3"
                value={@certificate_changeset.data.admin_title3}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
          </div>
          <!-- Logos -->
          <div class="self-stretch flex-col justify-start items-start gap-3 flex">
            <div class="text-base font-bold">
              Logos
            </div>
            <div class="text-base font-small">
              Upload up to three logos for your certificate.
            </div>
            <!-- File Input -->
            <.live_file_input upload={@uploads.logo} />
            <!-- Display Uploaded Previews -->
            <section>
              <%= for entry <- @uploads.logo.entries do %>
                <div>
                  <.live_img_preview entry={entry} class="preview" />
                  <a href="#" phx-click="cancel" phx-target={@myself} phx-value-ref={entry.ref}>
                    ✖
                  </a>
                </div>
              <% end %>
            </section>
          </div>
          <!-- Preview -->
          <button
            type="button"
            phx-click="preview_certificate"
            phx-target={@myself}
            class="px-6 py-4 bg-gray-500 text-white rounded hover:opacity-90"
          >
            Preview
          </button>

          <%= if @show_preview do %>
            <div class="fixed inset-0 z-50 flex items-center justify-center bg-gray-900">
              <div class="relative w-11/12 max-w-4xl bg-white rounded shadow-lg p-6">
                <!-- Modal Header -->
                <div class="flex justify-between items-center border-b pb-4 mb-4">
                  <h2 class="text-xl font-bold">Certificate Preview</h2>
                  <button
                    type="button"
                    phx-click="close_preview"
                    phx-target={@myself}
                    class="text-gray-500 hover:text-gray-800"
                  >
                    ✖
                  </button>
                </div>
                <!-- Modal Content -->
                <div class="overflow-y-auto max-h-[90vh] bg-gray-100">
                  <iframe
                    srcdoc={elem(@certificate_html, @preview_page)}
                    class="w-full h-auto border-0"
                    style="height: 80vh;"
                  >
                  </iframe>
                </div>
                <!-- Modal Footer -->
                <div class="flex justify-between mt-4">
                  <!-- Previous Button -->
                  <%= if @preview_page > 0 do %>
                    <button
                      type="button"
                      phx-click="prev_preview_page"
                      phx-target={@myself}
                      class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-700"
                    >
                      Previous
                    </button>
                  <% end %>
                  <!-- Next Button -->
                  <%= if @preview_page < 1 do %>
                    <button
                      type="button"
                      phx-click="next_preview_page"
                      phx-target={@myself}
                      class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-700"
                    >
                      Next
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
          <!-- Save -->
          <button
            type="submit"
            form={f.id}
            class="px-6 py-4 bg-[#0165da] text-white rounded opacity-90 hover:opacity-100"
          >
            Save Design
          </button>
          <div></div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :logo, ref)}
  end

  def handle_event("preview_certificate", _params, socket) do
    html1 = """
    <div class="text-center">
      <h1>Certificate of Completion</h1>
      <p>This certifies that</p>
      <p>John Doe</p>
      <p>has successfully completed the course</p>
      <p>Introduction to Chemistry</p>
      <p>Date: January 2025</p>
    </div>
    """

    html2 = """
    <div class="text-center">
      <h1>Certificate with Distinction</h1>
      <p>This certifies that</p>
      <p>John Doe</p>
      <p>has successfully completed the course</p>
      <p>Introduction to Chemistry</p>
      <p>Date: January 2025</p>
    </div>
    """

    {:noreply,
     assign(socket,
       show_preview: true,
       certificate_html: {html1, html2}
     )}
  end

  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, show_preview: false, certificate_html: nil)}
  end

  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("next_preview_page", _params, socket) do
    {:noreply, assign(socket, preview_page: 1)}
  end

  def handle_event("prev_preview_page", _params, socket) do
    {:noreply, assign(socket, preview_page: 0)}
  end

  defp certificate_changeset(nil), do: Certificate.changeset()
  defp certificate_changeset(%Certificate{} = cert), do: Certificate.changeset(cert, %{})
end
