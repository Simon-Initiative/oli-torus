defmodule OliWeb.TechSupportLive do
  use OliWeb, :live_view
  alias Oli.Help.HelpContent
  alias Oli.Help.HelpRequest
  alias OliWeb.Components.Modal

  @modal_id "tech-support-modal"
  @base_url Oli.Utils.get_base_url()

  @impl true
  def mount(_params, session, socket) do
    requires_sender_data = !Enum.any?(Map.take(session, ["current_user_id", "current_author_id"]))
    socket = assign(socket, requires_sender_data: requires_sender_data)

    socket =
      socket
      |> assign(:knowledgebase_url, Oli.VendorProperties.knowledgebase_url())
      |> assign_form(HelpRequest.changeset())
      |> assign(modal_id: @modal_id)
      |> assign(recaptcha_error: false)
      |> assign(:session, session)
      |> assign(uploaded_files: [])
      |> allow_upload(:attached_screenshots,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 3,
        auto_upload: true,
        max_file_size: 10_000_000
      )

    {:ok, socket, layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto z-50 top-0 absolute right-0">
      <.flash_group flash={@flash} />
    </div>
    <button
      id="trigger-tech-support-modal"
      class="hidden"
      phx-click={Modal.show_modal(@modal_id)}
      data-hide_modal={Modal.hide_modal(@modal_id)}
    />
    <Modal.modal id={@modal_id} class="md:w-8/12">
      <:title>Tech Support</:title>
      <a href={@knowledgebase_url}>Find answers quickly in the Torus knowledge base.</a>
      <div class="w-auto">
        <.form
          id="tech-support-modal-form"
          for={@form}
          phx-submit="submit"
          phx-change="validate"
          phx-hook="SubmitTechSupportForm"
        >
          <.input
            type="checkbox"
            field={@form[:requires_sender_data]}
            value="true"
            checked={@requires_sender_data}
            class="hidden"
          />
          <.input
            :if={@requires_sender_data}
            label="Name"
            type="text"
            field={@form[:name]}
            placeholder="Enter Name"
            class="mb-3 w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug"
            minlength="3"
            required
          />
          <.input
            :if={@requires_sender_data}
            label="Email"
            type="email"
            field={@form[:email_address]}
            placeholder="Enter Email"
            class="mb-3 w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug"
            required
          />
          <.input
            label="Subject:"
            label_position={:top}
            type="select"
            options={subject_options()}
            field={@form[:subject]}
            prompt="Select from the list of topics provided"
            required
            class="mb-3 w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug"
          />
          <.input
            label="Questions or Comments:"
            field={@form[:message]}
            type="textarea"
            class="w-full dark:placeholder:text-zinc-300 pl-6 dark:bg-stone-900 rounded-md border dark:border-zinc-300 dark:text-zinc-300 leading-snug"
            required
            rows="10"
          />

          <div class="hint">
            <p>
              Add up to <%= @uploads.attached_screenshots.max_entries %> screenshots
              (max <%= trunc(@uploads.attached_screenshots.max_file_size / 1_000_000) %> MB each)
            </p>
            <p>
              Please show full browser window including address bar.
            </p>
          </div>

          <div class="drop" phx-drop-target={@uploads.attached_screenshots.ref}>
            <.live_file_input upload={@uploads.attached_screenshots} />
            <div>
              or drag and drop here
            </div>
          </div>

          <.error :for={err <- upload_errors(@uploads.attached_screenshots)}>
            <%= Phoenix.Naming.humanize(err) %>
          </.error>

          <div :for={entry <- @uploads.attached_screenshots.entries} class="entry">
            <.live_img_preview entry={entry} />

            <div class="progress">
              <div class="value">
                <%= entry.progress %>%
              </div>
              <div class="bar">
                <span style={"width: #{entry.progress}%"}></span>
              </div>
              <.error :for={err <- upload_errors(@uploads.attached_screenshots, entry)}>
                <%= Phoenix.Naming.humanize(err) %>
              </.error>
            </div>

            <a phx-click="cancel" phx-value-ref={entry.ref}>
              &times;
            </a>
          </div>

          <div class="w-full flex flex-col lg:flex-row gap-2 md:justify-between">
            <.render_recaptcha recaptcha_error={@recaptcha_error} class="md:m-0 m-auto" />

            <div class="flex w-full justify-around lg:justify-end items-center">
              <.button type="link" variant={:link} phx-click={Modal.hide_modal(@modal_id)}>
                Cancel
              </.button>
              <.button type="submit" class="btn btn-primary h-fit">
                Send Request
              </.button>
            </div>
          </div>
        </.form>
      </div>
    </Modal.modal>
    """
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attached_screenshots, ref)}
  end

  @impl true
  def handle_event("validate", %{"help" => help}, socket) do
    changeset = HelpRequest.changeset(help)
    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("submit", %{"help" => help} = params, socket) do
    with {:success, true} <- Oli.Recaptcha.verify(params["g-recaptcha-response"]),
         %{valid?: true} = changeset <- HelpRequest.changeset(help) |> Map.put(:action, :validate) do
      params = add_metadata(socket, params, changeset)

      socket =
        socket
        |> push_hide_modal_js_event()
        |> push_event("run_tech_support_hook", params)
        |> assign(recaptcha_error: false)
        |> assign_form(HelpRequest.changeset())

      {:noreply, socket}
    else
      {:success, false} ->
        {:noreply, assign(socket, recaptcha_error: "reCAPTCHA failed, please try again")}

      changeset ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("form_response", %{"info" => info}, socket) do
    socket = put_flash(socket, :info, info)
    {:noreply, socket}
  end

  def handle_event("form_response", _params, socket) do
    message = "We are unable to forward your help request at the moment"
    socket = put_flash(socket, :error, message)
    {:noreply, socket}
  end

  defp add_metadata(socket, params, changeset) do
    session = socket.assigns.session
    uploaded_screenshots = consume_uploaded_screenshots(socket)

    params
    |> Map.update!("help", fn help ->
      help
      |> Map.put(:requester_data, get_requester_data(session, changeset))
      |> Map.put(:course_data, get_course_data(session))
      |> Map.put(:screenshots, uploaded_screenshots)
    end)
  end

  defp get_requester_data(session, changeset) do
    %{
      requester_name: get_full_name(session) || Ecto.Changeset.get_field(changeset, :name),
      requester_email: get_email(session) || Ecto.Changeset.get_field(changeset, :email_address),
      requester_type: get_user_type(session),
      requester_account_url: get_user_account_url(session),
      student_report_url: get_student_report_url(session)
    }
  end

  defp consume_uploaded_screenshots(socket) do
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
    random_string = Oli.Utils.random_string(16)

    consume_uploaded_entries(socket, :attached_screenshots, fn %{path: content}, entry ->
      image_file_name = "#{entry.uuid}.#{ext(entry)}"
      upload_path = Path.join(["screenshoots", random_string, image_file_name])

      Oli.Utils.S3Storage.upload_file(bucket_name, upload_path, content)
    end)
  end

  defp push_hide_modal_js_event(socket) do
    push_event(socket, "js-exec", %{
      to: "#trigger-tech-support-modal",
      attr: "data-hide_modal"
    })
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :help))
  end

  defp subject_options() do
    Enum.map(HelpContent.list_subjects(), fn {k, v} -> {v, k} end)
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end

  defp get_user_type(session) do
    case session["user"] do
      %Oli.Accounts.Author{} -> "Author"
      %Oli.Accounts.User{can_create_sections: true} -> "Instructor"
      %Oli.Accounts.User{} -> "Student"
      _ -> "Unknown"
    end
  end

  defp get_course_data(session) do
    if section = session["section"] do
      section = Oli.Repo.preload(section, [:institution, :publisher])
      institution_name = section.institution && section.institution.name

      section
      |> Map.take([:title, :start_date, :end_date])
      |> Map.merge(%{
        institution_name: institution_name,
        course_management_url: "#{@base_url}/sections/#{section.slug}/manage"
      })
    end
  end

  defp get_full_name(session) do
    if user = session["user"] do
      OliWeb.Common.Utils.name(user)
    end
  end

  defp get_email(session) do
    if user = session["user"] do
      user.email
    end
  end

  defp get_student_report_url(session) do
    if session["current_user_id"] do
      section = session["section"]
      user = session["user"]

      if section && user do
        "#{@base_url}/sections/#{section.slug}/student_dashboard/#{user.id}/content"
      end
    end
  end

  defp get_user_account_url(session) do
    if user = session["user"] do
      if session["current_user_id"] do
        "#{@base_url}/admin/users/#{user.id}"
      else
        "#{@base_url}/admin/authors/#{user.id}"
      end
    end
  end
end
