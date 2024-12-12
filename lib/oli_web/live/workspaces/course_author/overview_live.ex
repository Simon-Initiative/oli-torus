defmodule OliWeb.Workspaces.CourseAuthor.OverviewLive do
  use OliWeb, :live_view

  import Phoenix.Component
  import OliWeb.Components.Common

  alias Oli.{Accounts, Activities, Inventories, Publishing}
  alias Oli.Authoring.{Broadcaster, Course, ProjectExportWorker}
  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Authoring.Course.{CreativeCommons, Project}
  alias Oli.Delivery.Experiments
  alias Oli.LanguageCodesIso639
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Collaboration
  alias OliWeb.Common.Utils
  alias OliWeb.Components.{Common, Overview}
  alias OliWeb.Components.Project.AsyncExporter
  alias OliWeb.Projects.{RequiredSurvey, TransferPaymentCodes}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{project: project, current_author: author, ctx: ctx} = socket.assigns

    is_admin? = Accounts.has_admin_role?(author, :content_admin)

    latest_published_publication =
      Publishing.get_latest_published_publication_by_slug(project.slug)

    {collab_space_config, revision_slug} = get_collab_space_config_and_revision(project.slug)

    latest_publication = Publishing.get_latest_published_publication_by_slug(project.slug)

    cc_options =
      CreativeCommons.cc_options()
      |> Enum.map(fn {k, v} -> {v.text, k} end)
      |> Enum.sort(:desc)

    {project_export_status, project_export_url, project_export_timestamp} =
      case ProjectExportWorker.project_export_status(project) do
        {:available, url, timestamp} -> {:available, url, timestamp}
        {status} -> {status, nil, nil}
      end

    # Subscribe to any project export progress updates for this project
    Subscriber.subscribe_to_project_export_status(project.slug)

    {:ok,
     assign(socket,
       ctx: ctx,
       collaborators: Accounts.project_authors(project),
       activities_enabled: Activities.advanced_activities(project, is_admin?),
       can_enable_experiments: is_admin? and Experiments.experiments_enabled?(),
       is_admin: is_admin?,
       changeset: Project.changeset(project),
       latest_published_publication: latest_published_publication,
       publishers: Inventories.list_publishers(),
       resource_title: project.title,
       resource_slug: project.slug,
       attributes: project.attributes,
       language_codes: LanguageCodesIso639.codes(),
       license_opts: cc_options,
       collab_space_config: collab_space_config,
       revision_slug: revision_slug,
       latest_publication: latest_publication,
       notes_config: %{},
       project_export_status: project_export_status,
       project_export_url: project_export_url,
       project_export_timestamp: project_export_timestamp
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="overview">
      <h2 id="header_id" class="pb-2">Overview</h2>
      <.form :let={f} for={@changeset} phx-submit="update" phx-change="validate">
        <Overview.section
          title="Details"
          description="Your project title and description will be shown to students when you publish this project."
        >
          <div class="form-label-group mb-3">
            <.input field={f[:slug]} label="Project ID" class="form-control" disabled />
          </div>
          <div class="form-label-group mb-3">
            <.input
              field={f[:title]}
              label="Project Title"
              class="form-control"
              placeholder="The title of your project..."
              error_position={:top}
              errors={f.errors}
            />
          </div>
          <div class="form-label-group mb-3">
            <.input
              field={f[:description]}
              label="Project Description"
              type="textarea"
              class="form-control"
              placeholder="A brief description of your project..."
              error_position={:top}
              errors={f.errors}
            />
          </div>
          <% welcome_title =
            (fetch_field(f.source, :welcome_title) &&
               fetch_field(f.source, :welcome_title)["children"]) || [] %>
          <.rich_text_editor_field
            id="welcome_title_field"
            form={f}
            value={welcome_title}
            field_name={:welcome_title}
            field_label="Welcome Message Title"
            on_edit="welcome_title_change"
            project_slug={@project.slug}
            ctx={@ctx}
          />
          <div class="form-label-group mb-3">
            <.input
              field={f[:encouraging_subtitle]}
              label="Encouraging Subtitle"
              type="textarea"
              class="form-control"
              placeholder="Enter a subtitle to encourage students to begin the course..."
              error_position={:top}
              errors={f.errors}
            />
          </div>
          <div class="form-label-group mb-3">
            <Common.label class="control-label">Latest Publication</Common.label>
            <%= case @latest_published_publication do %>
              <% %{edition: edition, major: major, minor: minor} -> %>
                <p class="text-secondary">
                  <%= Utils.render_version(edition, major, minor) %>
                </p>
              <% _ -> %>
                <p class="text-secondary">This project has not been published</p>
            <% end %>
          </div>
          <div class="form-label-group mb-3">
            <.input
              field={f[:publisher_id]}
              label="Project Publisher"
              type="select"
              class="form-control"
              options={Enum.map(@publishers, &{&1.name, &1.id})}
              error_position={:top}
              errors={f.errors}
            />
          </div>

          <div class="form-label-group mb-3">
            <div :if={@can_enable_experiments} class="form-label-group mb-3 form-check">
              <.input
                field={f[:has_experiments]}
                label="Enable Upgrade-based Experiments"
                type="checkbox"
                error_position={:bottom}
                errors={f.errors}
              />
            </div>

            <.link
              :if={@project.has_experiments}
              class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline"
              navigate={~p"/workspaces/course_author/#{@project.slug}/experiments"}
            >
              Manage Experiments
            </.link>
          </div>

          <%= submit("Save", class: "btn btn-md btn-primary mt-2") %>
        </Overview.section>
        <Overview.section
          title="Project Attributes"
          description="Project wide configuration, not all options may be relevant for all subject areas."
        >
          <div class="d-block">
            <%= inputs_for f, :attributes, fn fp -> %>
              <div :if={@is_admin} class="form-label-group mb-3">
                <%= checkbox(fp, :calculate_embeddings_on_publish) %>
                <%= label(fp, :calculate_embeddings_on_publish, "Calculate embeddings on publish",
                  class: "control-label"
                ) %>
              </div>
              <div class="form-label-group mb-3">
                <%= label(fp, :learning_language, "Learning Language (optional)",
                  class: "control-label"
                ) %>
                <%= select(fp, :learning_language, @language_codes,
                  class: "form-control",
                  required: false,
                  prompt: "What language is being taught in this project?"
                ) %>
              </div>
              <%= inputs_for fp, :license, fn fpp -> %>
                <%= label(fpp, :license_type, "License (optional)", class: "control-label") %>
                <%= select(fpp, :license_type, @license_opts,
                  phx_change: "on_selected",
                  class: "form-control",
                  required: false
                ) %>
                <div :if={open_custom_type?(@changeset)} class="form-label-group mb-3">
                  <%= label(fpp, :custom_license_details, "Custom license (URL)",
                    class: "control-label"
                  ) %>
                  <%= text_input(fpp, :custom_license_details,
                    class: "form-control",
                    placeholder: "https://creativecommons.org/licenses/by/4.0/",
                    required: false
                  ) %>
                </div>
              <% end %>
            <% end %>
          </div>
          <div>
            <%= submit("Save", class: "btn btn-md btn-primary mt-2") %>
          </div>
          <div class="mt-5">
            <div>
              <.link
                navigate={~p"/workspaces/course_author/#{@project.slug}/alternatives"}
                class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline"
              >
                Manage Alternatives
              </.link>
            </div>
            <small>
              Alternatives define the different flavors of content which can be authored. Students can then select which alternative they prefer to use.
            </small>
          </div>
        </Overview.section>

        <%= if @is_admin do %>
          <Overview.section title="Content Types" description="Enable optional content types.">
            <div class="form-label-group mb-3 form-check">
              <%= checkbox(f, :allow_ecl_content_type, required: false) %>
              <%= label(f, :allow_ecl_content_type, "ECL Code Editor",
                class: "control-label form-check-label"
              ) %>
            </div>

            <%= submit("Save", class: "btn btn-md btn-primary mt-2") %>
          </Overview.section>
        <% end %>
      </.form>

      <Overview.section title="Project Labels" description="Project wide customization of labels.">
        <%= live_render(@socket, OliWeb.Projects.CustomizationLive,
          id: "project_customizations",
          session: %{"project_slug" => @project.slug}
        ) %>
      </Overview.section>

      <Overview.section
        title="Collaborators"
        description="Invite other authors by email to contribute to your project. Specify multiple separated by a comma."
      >
        <script src="https://www.google.com/recaptcha/api.js">
        </script>
        <.form
          :let={f}
          for={%Plug.Conn{}}
          id="form-add-collaborator"
          method="POST"
          action={Routes.collaborator_path(@socket, :create, @project)}
        >
          <div class="form-group">
            <div class="input-group mb-3">
              <%= text_input(
                f,
                :collaborator_emails,
                class: "form-control" <> error_class(f, :title, "is-invalid"),
                placeholder: "collaborator@example.edu",
                id: "input-title",
                required: true,
                autocomplete: "off",
                autofocus: focusHelper(f, :collaborator_emails, default: false)
              ) %>
              <%= error_tag(f, :collaborator_emails) %>
              <%= hidden_input(f, :authors,
                value: @collaborators |> Enum.map(fn author -> author.email end) |> Enum.join(", ")
              ) %>
              <div class="input-group-append">
                <%= submit("Send Invite",
                  id: "button-create-collaborator",
                  class: "btn btn-outline-primary",
                  phx_disable_with: "Adding Collaborator...",
                  form: f.id
                ) %>
              </div>
            </div>
            <div id="recaptcha" class="input-group mb-3" phx-update="ignore">
              <div
                class="g-recaptcha"
                data-sitekey={Application.fetch_env!(:oli, :recaptcha)[:site_key]}
              />
            </div>
            <%= error_tag(f, :captcha) %>
          </div>
        </.form>
        <%= render_many(@collaborators, OliWeb.ProjectView, "_collaborator.html", %{
          conn: @socket,
          as: :collaborator,
          project: @project
        }) %>
      </Overview.section>

      <Overview.section
        title="Advanced Activities"
        description="Enable advanced activity types for your project to include in your curriculum."
      >
        <%= render_many(@activities_enabled, OliWeb.ProjectView, "_tr_activities_available.html", %{
          conn: @socket,
          as: :activity_enabled,
          project: @project
        }) %>
      </Overview.section>

      <%= live_render(@socket, OliWeb.Projects.VisibilityLive,
        id: "project_visibility",
        session: %{"project_slug" => @project.slug}
      ) %>

      <%= live_render(@socket, OliWeb.CollaborationLive.CollabSpaceConfigView,
        id: "project_collab_space_config",
        session: %{
          "collab_space_config" => @collab_space_config,
          "project_slug" => @project.slug,
          "resource_slug" => @revision_slug,
          "is_overview_render" => true
        }
      ) %>

      <Overview.section
        title="Required Survey"
        description="Allows to activate and configure a survey for all students that enter the course for the first time."
      >
        <.live_component
          module={RequiredSurvey}
          id="required-survey-section"
          project={@project}
          author_id={@current_author.id}
          enabled={@project.required_survey_resource_id}
          required_survey={@project.required_survey}
        />
      </Overview.section>

      <Overview.section
        title="Transfer Payment Codes"
        description="Allows to transfer payment codes between products of this project."
      >
        <.live_component
          module={TransferPaymentCodes}
          id="transfer-payment-codes-section"
          project={@project}
        />
      </Overview.section>

      <Overview.section title="Actions" is_last={true}>
        <%= if @is_admin do %>
          <div class="flex items-center">
            <.link
              class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pr-3 py-2"
              href={~p"/workspaces/course_author/#{@project.slug}/index_csv"}
            >
              Bulk Resource Attribute Edit
            </.link>
            <span>Imports a <code>.csv</code> file to set new attributes.</span>
          </div>
        <% end %>

        <div class="flex items-center">
          <div>
            <%= button("Duplicate",
              to: Routes.project_path(@socket, :clone_project, @project),
              method: :post,
              class:
                "text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pr-3 py-2",
              data_confirm: "Are you sure you want to duplicate this project?"
            ) %>
          </div>
          <span>Create a complete copy of this project.</span>
        </div>

        <div class="flex items-center">
          <AsyncExporter.project_export
            ctx={@ctx}
            project_export_status={@project_export_status}
            project_export_url={@project_export_url}
            project_export_timestamp={@project_export_timestamp}
          />
        </div>

        <div :if={@is_admin} class="flex items-center">
          <%= case @latest_publication do %>
            <% nil -> %>
              <.button
                variant={:link}
                class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pr-3 py-2"
                disabled
              >
                Datashop Analytics
              </.button>
              <span>
                Project must be published to create a <.datashop_link /> snapshot for download
              </span>
            <% _pub -> %>
              <.link
                class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline pr-3 py-2"
                navigate={~p"/workspaces/course_author/#{@project.slug}/datashop"}
              >
                Datashop Analytics
              </.link>
              <span>Create a <.datashop_link /> snapshot for download</span>
          <% end %>
        </div>

        <div class="flex items-center mt-8">
          <button
            type="button"
            class="text-[#ef4444] hover:text-[#dc2626] dark:text-[#dc2626] dark:hover:text-[#ef4444] hover:underline pr-3 py-2"
            onclick="OLI.showModal('delete-package-modal')"
          >
            Delete
          </button>
          <span>Permanently delete this project.</span>
        </div>
      </Overview.section>
    </div>

    <div
      class="modal fade"
      id="delete-package-modal"
      tabindex="-1"
      role="dialog"
      aria-labelledby="delete-modal"
      aria-hidden="true"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Are you absolutely sure?</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            <div class="container form-container">
              <div class="mb-3">
                This action will not affect existing course sections that are using this project.
                Those sections will continue to operate as intended
              </div>
              <div>
                <p>Please type <strong><%= @project.title %></strong> below to confirm.</p>
              </div>
              <.form :let={f} for={%{}} as={:form} phx-submit="delete">
                <div class="mt-2">
                  <%= text_input(f, :title,
                    class: "form-control",
                    id: "delete-confirm-title",
                    required: true
                  ) %>
                </div>
                <div class="d-flex">
                  <button
                    id="delete-modal-submit"
                    type="submit"
                    class="btn btn-outline-danger mt-2 flex-fill"
                    disabled
                  >
                    Delete this course
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </div>

    <script>
      OLI.onReady(() => OLI.enableSubmitWhenTitleMatches('#delete-confirm-title', '#delete-modal-submit', '<%= Base.encode64(@project.title) %>'));
    </script>
    """
  end

  defp open_custom_type?(changeset) do
    with %Ecto.Changeset{} = changeset <- Ecto.Changeset.get_embed(changeset, :attributes),
         %Ecto.Changeset{} = changeset <- Ecto.Changeset.get_embed(changeset, :license),
         :custom <- Ecto.Changeset.get_field(changeset, :license_type) do
      true
    else
      _ -> false
    end
  end

  defp get_collab_space_config_and_revision(project_slug) do
    %{slug: revision_slug} = AuthoringResolver.root_container(project_slug)

    {:ok, collab_space_config} =
      Collaboration.get_collab_space_config_for_page_in_project(
        revision_slug,
        project_slug
      )

    {collab_space_config, revision_slug}
  end

  @impl Phoenix.LiveView
  def handle_event("on_selected", %{"project" => project_attrs}, socket) do
    project = socket.assigns.project
    {:noreply, assign(socket, changeset: Project.changeset(project, project_attrs))}
  end

  def handle_event("update", %{"project" => project_params}, socket) do
    project_params =
      project_params
      |> add_custom_license_details()
      |> decode_welcome_title()

    project = socket.assigns.project

    socket =
      case Course.update_project(project, project_params) do
        {:ok, project} ->
          socket
          |> assign(:project, project)
          |> assign(:changeset, Project.changeset(project))
          |> put_flash(:info, "Project updated successfully.")

        {:error, %Ecto.Changeset{} = changeset} ->
          socket
          |> assign(:changeset, changeset)
          |> put_flash(:error, "Project could not be updated.")
      end

    {:noreply, socket}
  end

  def handle_event("delete", _params, socket) do
    project = socket.assigns.project

    case Course.update_project(project, %{status: :deleted}) do
      {:ok, _project} ->
        {:noreply,
         redirect(socket,
           to: ~p"/workspaces/course_author"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:changeset, changeset)
          |> put_flash(:error, "Project could not be deleted.")

        {:noreply, socket}
    end
  end

  def handle_event("welcome_title_change", %{"values" => welcome_title}, socket) do
    changeset =
      Ecto.Changeset.put_change(socket.assigns.changeset, :welcome_title, %{
        "type" => "p",
        "children" => welcome_title
      })

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("validate", %{"project" => project_params}, socket) do
    project_params =
      project_params
      |> add_custom_license_details()
      |> decode_welcome_title()

    changeset =
      socket.assigns.project
      |> Course.change_project(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("generate_project_export", _params, socket) do
    project = socket.assigns.project

    case ProjectExportWorker.generate_project_export(project) do
      {:ok, _job} ->
        Broadcaster.broadcast_project_export_status(project.slug, {:in_progress})

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Project export could not be generated.")

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:project_export_status, {:available, project_export_url, project_export_timestamp}},
        socket
      ) do
    {:noreply,
     assign(socket,
       project_export_status: :available,
       project_export_url: project_export_url,
       project_export_timestamp: project_export_timestamp
     )}
  end

  def handle_info(
        {:project_export_status, {:error, _e}},
        socket
      ) do
    {:noreply,
     assign(socket,
       project_export_status: :error
     )}
  end

  def handle_info({:project_export_status, {status}}, socket) do
    {:noreply, assign(socket, project_export_status: status)}
  end

  defp add_custom_license_details(%{"license" => "custom"} = project_params), do: project_params

  defp add_custom_license_details(project_params),
    do: Map.put(project_params, "custom_license_details", nil)

  defp decode_welcome_title(%{"welcome_title" => nil} = project_params), do: project_params

  defp decode_welcome_title(%{"welcome_title" => ""} = project_params),
    do: %{project_params | "welcome_title" => nil}

  defp decode_welcome_title(project_params),
    do: Map.update(project_params, "welcome_title", nil, &Poison.decode!(&1))

  defp datashop_link(assigns) do
    ~H"""
    <a
      class="text-[#006CD9] hover:text-[#1B67B2] dark:text-[#4CA6FF] dark:hover:text-[#99CCFF] hover:underline py-2 external"
      href="https://pslcdatashop.web.cmu.edu/"
      target="_blank"
    >
      datashop
    </a>
    """
  end
end
