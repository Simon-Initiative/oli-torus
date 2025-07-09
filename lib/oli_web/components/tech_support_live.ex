defmodule OliWeb.TechSupportLive do
  use OliWeb, :live_view
  alias Oli.Help.HelpContent
  alias Oli.Help.HelpRequest
  alias OliWeb.Components.Modal

  @modal_id "tech-support-modal"
  @base_url Oli.Utils.get_base_url()

  require Logger

  @impl true
  def mount(_params, session, socket) do
    requires_sender_data = !Enum.any?(Map.take(session, ["current_user_id", "current_author_id"]))
    publisher = Oli.Inventories.get_publisher_for_context(session)
    knowledge_base_link = Oli.Inventories.knowledge_base_link_for_publisher(publisher)
    support_email = Oli.Inventories.support_email_for_publisher(publisher)

    socket =
      socket
      |> assign(:requires_sender_data, requires_sender_data)
      |> assign_form(HelpRequest.changeset())
      |> assign(:modal_id, @modal_id)
      |> assign(:recaptcha_error, false)
      |> assign(:session, session)
      |> assign(:submission_result, nil)
      |> assign(:uploaded_files, [])
      |> assign(:knowledge_base_link, knowledge_base_link)
      |> assign(:support_email, support_email)
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
    <button
      id="trigger-tech-support-modal"
      class="hidden"
      phx-click={Modal.show_modal(@modal_id)}
      data-hide_modal={Modal.hide_modal(@modal_id)}
    />
    <Modal.modal id={@modal_id} class="md:w-8/12" on_cancel={JS.push("clear_result_request_message")}>
      <:title>Tech Support</:title>

      <.process_result_message submission_result={@submission_result} knowledge_base_link={@knowledge_base_link} />

      <.form
        :if={!@submission_result}
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
          phx-debounce="500"
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
          <%!-- Start Captcha --%>
          <div class="w-80 mx-auto">
            <div
              id="recaptcha"
              phx-hook="Recaptcha"
              data-sitekey={Application.fetch_env!(:oli, :recaptcha)[:site_key]}
              data-theme="dark"
              phx-update="ignore"
            >
            </div>

            <.error :if={@recaptcha_error}><%= @recaptcha_error %></.error>
          </div>

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
    </Modal.modal>
    """
  end

  defp process_result_message(%{submission_result: nil} = assigns) do
    ~H"""
    <a href={@knowledge_base_link} target="_blank">
      Find answers quickly in the knowledge base.
    </a>
    """
  end

  defp process_result_message(assigns) do
    assigns = assign(assigns, modal_id: @modal_id)

    ~H"""
    <div class="flex flex-col items-center justify-center pb-4 text-center">
      <span :if={@submission_result == :success}>
        Your help request has been successfully submitted.
      </span>
      <span :if={@submission_result == :error} class="text-danger">
        We are unable to forward your help request at the moment.
      </span>
      <.button
        variant={:primary}
        phx-click={Modal.hide_modal(@modal_id) |> JS.push("clear_result_request_message")}
        class="mt-4"
      >
        Ok
      </.button>
    </div>
    """
  end

  def handle_event("clear_result_request_message", _params, socket) do
    {:noreply, assign(socket, submission_result: nil)}
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attached_screenshots, ref)}
  end

  @impl true
  def handle_event("validate", %{"help" => help}, socket) do
    {:noreply, assign_form(socket, HelpRequest.changeset(help))}
  end

  def handle_event("submit", %{"help" => help} = params, socket) do
    with {:success, true} <- Oli.Recaptcha.verify(params["g-recaptcha-response"]),
         %{valid?: true} = changeset <-
           HelpRequest.changeset(help) |> Map.put(:action, :validate) do
      socket =
        socket
        |> assign_form(HelpRequest.changeset())
        |> assign(changeset: changeset)
        |> push_event("run_tech_support_hook", help)

      {:noreply, socket}
    else
      {:success, false} ->
        {:noreply, assign(socket, recaptcha_error: "reCAPTCHA failed, please try again")}

      changeset ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("client_response", params, socket) do
    session = socket.assigns.session
    changeset = socket.assigns.changeset

    with {:ok, requester_data} <- get_requester_data(session, changeset),
         raw_params <- build_params(socket, requester_data, session, params),
         {:ok, help_content} <- HelpContent.parse(raw_params),
         {:ok, _} <- dispatch_email(help_content) do
      socket = socket |> assign(submission_result: :success)
      {:noreply, socket}
    else
      {:error, message} ->
        Logger.error("Error when processing help message. #{inspect(message)}")
        socket = socket |> assign(submission_result: :error)
        {:noreply, socket}
    end
  end

  def build_params(socket, requester_data, session, params) do
    keys =
      ~w(agent_accept agent_language browser_timezone ip_address section timestamp user user_agent)

    course_data = get_course_data(session)
    uploaded_screenshots = consume_uploaded_screenshots(socket)
    account_created = get_account_created_info(session)

    socket.assigns.session
    |> Map.take(keys)
    |> Map.merge(params)
    |> Map.put("course_data", course_data)
    |> Map.put("screenshots", uploaded_screenshots)
    |> Map.put("account_created", account_created)
    |> Map.put("requester_data", requester_data)
    |> Map.put("support_email", socket.assigns.support_email)
  end

  defp dispatch_email(help_content) do
    dispatcher = Application.fetch_env!(:oli, :help)[:dispatcher]
    Oli.Help.Dispatcher.dispatch(dispatcher, help_content)
  end

  defp get_requester_data(session, changeset) do
    name = get_full_name(session) || Ecto.Changeset.get_field(changeset, :name)
    email = get_email(session) || Ecto.Changeset.get_field(changeset, :email_address)

    if name && email do
      {:ok,
       %Oli.Help.RequesterData{
         requester_name: name,
         requester_email: email,
         requester_type: get_user_type(session),
         requester_account_url: get_user_account_url(session),
         student_report_url: get_student_report_url(session)
       }}
    else
      eval_name = if is_nil(name), do: ["name"], else: []
      eval_email = if is_nil(email), do: ["email"], else: []
      required_fields = Enum.join(eval_name ++ eval_email, " and ")
      {:error, "Requester data is incomplete. Required field(s): #{required_fields}"}
    end
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
      |> then(fn m -> struct(Oli.Help.CourseData, m) end)
    end
  end

  defp get_account_created_info(session) do
    if user = session["user"] do
      OliWeb.Common.Utils.render_precise_date(user, :inserted_at, session["context"])
    else
      ""
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
