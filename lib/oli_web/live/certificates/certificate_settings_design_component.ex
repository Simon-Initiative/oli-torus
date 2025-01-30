defmodule OliWeb.Certificates.CertificateSettingsDesignComponent do
  use OliWeb, :live_component

  alias Oli.Delivery.Certificates.CertificateRenderer
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Repo

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
        for={@certificate}
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
                placeholder={@product.title}
                errors={f.errors}
                phx-debounce="blur"
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
                placeholder={@product.description}
                errors={f.errors}
                phx-debounce="blur"
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
                errors={f.errors}
                phx-debounce="blur"
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title1]}
                placeholder="Title 1"
                errors={f.errors}
                phx-debounce="blur"
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
            <div class="flex gap-3 items-center">
              <.input
                type="text"
                field={f[:admin_name2]}
                placeholder="Name 2"
                errors={f.errors}
                phx-debounce="blur"
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title2]}
                placeholder="Title 2"
                errors={f.errors}
                phx-debounce="blur"
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
            <div class="flex gap-3 items-center">
              <.input
                type="text"
                field={f[:admin_name3]}
                placeholder="Name 3"
                errors={f.errors}
                phx-debounce="blur"
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title3]}
                placeholder="Title 3"
                errors={f.errors}
                phx-debounce="blur"
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
              Upload up to three logos for your certificate (Max size: 1MB each).
            </div>
            <!-- File Input -->
            <.live_file_input upload={@uploads.logo} />
            <!-- Display Uploaded Previews -->
            <section class="flex gap-4 flex-wrap mt-4">
              <%= for entry <- @uploads.logo.entries do %>
                <div class="relative w-24 h-24 flex-shrink-0">
                  <.live_img_preview
                    entry={entry}
                    class="object-cover w-full h-full rounded border border-gray-300"
                  />
                  <a
                    href="#"
                    class="absolute top-1 right-1 bg-white rounded-full w-5 h-5 flex items-center justify-center text-red-500 shadow hover:bg-red-100"
                    phx-click="cancel"
                    phx-target={@myself}
                    phx-value-ref={entry.ref}
                  >
                    ✖
                  </a>
                </div>
              <% end %>
            </section>
          </div>
          <!-- Preview -->
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
            name="save"
            form={f.id}
            phx-disable-with="Saving..."
            class="px-6 py-4 bg-[#0165da] text-white rounded opacity-90 hover:opacity-100"
          >
            Preview
          </button>
          <div></div>
        </div>
      </.form>
    </div>
    """
  end

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
     |> assign(assigns)
     |> assign(
       show_preview: false,
       preview_page: 0,
       certificate_html: {nil, nil}
     )
     |> assign_new(:form, fn ->
       to_form(Certificate.changeset(assigns.certificate || %Certificate{}, %{}))
     end)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    certificate = socket.assigns.certificate || %Certificate{}
    changeset = Certificate.changeset(certificate, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :logo, ref)}
  end

  def handle_event("save", _params, socket) do
    certificate_html = generate_previews(socket)

    {:noreply,
     assign(socket,
       show_preview: true,
       certificate_html: certificate_html
     )}

    # TODO:
    # - title, description if empty copy them from product

    # certificate = socket.assigns.certificate || %Certificate{}
    # certificate
    # |> Certificate.changeset()
    # |> Repo.insert_or_update()
    # |> case do
    #   {:ok, _certificate} ->
    #     {:noreply,
    #      assign(socket,
    #        show_preview: true,
    #        certificate_html: certificate_html
    #      )}

    #   {:error, %Ecto.Changeset{} = changeset} ->
    #     {:noreply,
    #      assign(socket,
    #        form: to_form(changeset),
    #        show_preview: true,
    #        certificate_html: certificate_html
    #      )}
    # end
  end

  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, show_preview: false, certificate_html: nil)}
  end

  def handle_event("next_preview_page", _params, socket) do
    {:noreply, assign(socket, preview_page: 1)}
  end

  def handle_event("prev_preview_page", _params, socket) do
    {:noreply, assign(socket, preview_page: 0)}
  end

  defp generate_previews(%{assigns: assigns} = socket) do
    admins =
      [
        {assigns.form.params["admin_name1"], assigns.form.params["admin_title1"]},
        {assigns.form.params["admin_name2"], assigns.form.params["admin_title2"]},
        {assigns.form.params["admin_name3"], assigns.form.params["admin_title3"]}
      ]
      |> Enum.reject(fn {name, _} -> name == "" end)

    logos =
      socket
      |> consume_uploaded_entries(:logo, fn %{path: path}, entry ->
        b64 = path |> File.read!() |> Base.encode64()
        {:ok, "data:#{entry.client_type};base64, #{b64}"}
      end)

    attrs = %{
      certificate_type: "Certificate of Completion",
      student_name: "Student Name",
      completion_date: Date.utc_today() |> Calendar.strftime("%B %d, %Y"),
      certificate_id: "00000000-0000-0000-0000-000000000000",
      course_name: assigns.form.params["title"] || assigns.product.title,
      course_description: assigns.form.params["description"] || assigns.product.description,
      administrators: admins,
      logos: logos
    }

    completion_cert = CertificateRenderer.render(attrs)

    distinction_cert =
      CertificateRenderer.render(%{attrs | certificate_type: "Certificate with Distinction"})

    {completion_cert, distinction_cert}
  end
end
