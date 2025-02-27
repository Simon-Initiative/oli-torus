defmodule OliWeb.Certificates.Components.DesignTab do
  use OliWeb, :live_component

  alias Oli.Delivery.Certificates.CertificateRenderer
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Repo
  alias OliWeb.Icons

  @impl true
  def render(%{read_only: true} = assigns) do
    ~H"""
    <div>
      <.preview_certificate
        certificate_html={@certificate_html}
        preview_page={@preview_page}
        target={@myself}
      />
    </div>
    """
  end

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
            <section class="flex gap-4 flex-wrap mt-4">
              <!-- Display existing logos -->
              <%= for logo <- saved_logos(@certificate_changeset) do %>
                <div class="relative w-24 h-24 flex-shrink-0">
                  <img src={logo} class="object-cover w-full h-full rounded border border-gray-300" />
                </div>
              <% end %>
              <!-- Display uploaded previews -->
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
          <div>
            <!-- Save -->
            <button
              type="submit"
              name="save"
              form={f.id}
              phx-disable-with="Saving..."
              class="px-6 py-4 bg-blue-500 text-white rounded opacity-90 hover:opacity-100"
            >
              Save Design
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  def preview_certificate(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex flex-row justify-center overflow-hidden">
        <button
          role="prev button"
          phx-click="prev_preview_page"
          phx-target={@target}
          disabled={@preview_page == 0}
          class="enabled:hover:scale-105 disabled:opacity-50"
        >
          <Icons.left_arrow class="fill-[#3E3F44] dark:fill-white" />
        </button>

        <iframe
          id={"certificate_preview_#{@preview_page}"}
          srcdoc={elem(@certificate_html, @preview_page)}
          class="w-[65rem] h-[40rem]"
        >
        </iframe>
        <button
          role="next button"
          phx-click="next_preview_page"
          phx-target={@target}
          disabled={@preview_page == 1}
          class="enabled:hover:scale-105 disabled:opacity-50"
        >
          <Icons.left_arrow class="fill-[#3E3F44] dark:fill-white -rotate-180" />
        </button>
      </div>
      <div class="flex gap-4 justify-center">
        <button
          role="carousel prev button"
          phx-click="prev_preview_page"
          phx-target={@target}
          disabled={@preview_page == 0}
          class="enabled:hover:scale-105"
        >
          <.carousel_dot active={@preview_page == 0} />
        </button>
        <button
          role="carousel next button"
          phx-click="next_preview_page"
          phx-target={@target}
          disabled={@preview_page == 1}
          class="enabled:hover:scale-105"
        >
          <.carousel_dot active={@preview_page == 1} />
        </button>
      </div>
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
       certificate_html: maybe_generate_previews(assigns.read_only, assigns.certificate)
     )
     |> assign_new(:certificate_changeset, fn -> certificate_changeset(assigns.certificate) end)}
  end

  @impl true
  def handle_event("validate", %{"certificate" => params}, socket) do
    changeset = Certificate.changeset(socket.assigns.certificate, params)
    {:noreply, assign(socket, certificate_changeset: changeset)}
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :logo, ref)}
  end

  def handle_event("save", _params, %{assigns: assigns} = socket) do
    {completion_cert, distinction_cert, logos} = generate_previews(socket)

    attrs =
      assigns.certificate_changeset.changes
      |> Map.put(:logo1, Enum.at(logos, 0))
      |> Map.put(:logo2, Enum.at(logos, 1))
      |> Map.put(:logo3, Enum.at(logos, 2))

    socket.assigns.certificate
    |> Certificate.changeset(attrs)
    |> Repo.insert_or_update()
    |> case do
      {:ok, _certificate} ->
        {:noreply,
         assign(socket,
           show_preview: true,
           certificate_html: {completion_cert, distinction_cert}
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, certificate_changeset: changeset)}
    end
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
    changeset = assigns.certificate_changeset

    admins =
      [
        {changeset.changes[:admin_name1] || changeset.data.admin_name1,
         changeset.changes[:admin_title1] || changeset.data.admin_title1},
        {changeset.changes[:admin_name2] || changeset.data.admin_name2,
         changeset.changes[:admin_title2] || changeset.data.admin_title2},
        {changeset.changes[:admin_name3] || changeset.data.admin_name3,
         changeset.changes[:admin_title3] || changeset.data.admin_title3}
      ]
      |> Enum.reject(fn {name, _} -> name == "" || !name end)

    logos =
      socket
      |> consume_uploaded_entries(:logo, fn %{path: path}, entry ->
        b64 = path |> File.read!() |> Base.encode64()
        {:ok, "data:#{entry.client_type};base64, #{b64}"}
      end)
      |> case do
        [] -> saved_logos(changeset)
        new_logos -> new_logos
      end

    attrs = %{
      certificate_type: "Certificate of Completion",
      student_name: "Student Name",
      completion_date: Date.utc_today() |> Calendar.strftime("%B %d, %Y"),
      certificate_id: "00000000-0000-0000-0000-000000000000",
      course_name: changeset.changes[:title] || changeset.data.title,
      course_description: changeset.changes[:description] || changeset.data.description,
      administrators: admins,
      logos: logos
    }

    completion_cert = CertificateRenderer.render(attrs)

    distinction_cert =
      CertificateRenderer.render(%{attrs | certificate_type: "Certificate with Distinction"})

    {completion_cert, distinction_cert, logos}
  end

  defp certificate_changeset(nil), do: Certificate.changeset()
  defp certificate_changeset(%Certificate{} = cert), do: Certificate.changeset(cert, %{})

  defp saved_logos(changeset) do
    [changeset.data.logo1, changeset.data.logo2, changeset.data.logo3]
    |> Enum.reject(&is_nil/1)
  end

  defp carousel_dot(%{active: true} = assigns) do
    ~H"""
    <div class="w-3 h-3 bg-[#383A44] rounded-full"></div>
    """
  end

  defp carousel_dot(%{active: false} = assigns) do
    ~H"""
    <div class="w-3 h-3 bg-[#A3A3A3] rounded-full"></div>
    """
  end

  defp maybe_generate_previews(false, _), do: {nil, nil}

  defp maybe_generate_previews(true, certificate) do
    admins =
      [
        {certificate.admin_name1, certificate.admin_title1},
        {certificate.admin_name2, certificate.admin_title2},
        {certificate.admin_name3, certificate.admin_title3}
      ]
      |> Enum.reject(fn {name, _} -> name == "" || !name end)

    logos =
      [certificate.logo1, certificate.logo2, certificate.logo3]
      |> Enum.reject(&is_nil/1)

    granted_certificate_guid = "00000000-0000-0000-0000-000000000000"

    attrs = %{
      certificate_type: "Certificate of Completion",
      certificate_verification_url:
        url(OliWeb.Endpoint, ~p"/certificates?cert_guid=#{granted_certificate_guid}"),
      student_name: "Student Name",
      completion_date: Date.utc_today() |> Calendar.strftime("%B %d, %Y"),
      certificate_id: granted_certificate_guid,
      course_name: certificate.title,
      course_description: certificate.description,
      administrators: admins,
      logos: logos
    }

    completion_cert = CertificateRenderer.render(attrs)

    distinction_cert =
      CertificateRenderer.render(%{attrs | certificate_type: "Certificate with Distinction"})

    {completion_cert, distinction_cert}
  end
end
