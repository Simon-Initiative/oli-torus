defmodule OliWeb.Projects.OverviewLive do
  use OliWeb, :live_view

  import Phoenix.Component
  import OliWeb.Components.Common

  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Inventories
  alias Oli.Publishing
  alias OliWeb.Common.Breadcrumb
  alias Oli.Activities
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Collaboration
  alias OliWeb.Components.Overview
  alias OliWeb.Projects.{RequiredSurvey, TransferPaymentCodes}
  alias OliWeb.Common.{React, SessionContext}

  def mount(_params, session, socket) do
    ctx = SessionContext.init(socket, session)
    project = socket.assigns.project

    author = socket.assigns[:current_author]
    is_admin? = Accounts.has_admin_role?(author)

    latest_published_publication =
      Publishing.get_latest_published_publication_by_slug(project.slug)

    {collab_space_config, revision_slug} = get_collab_space_config_and_revision(project.slug)

    latest_publication = Publishing.get_latest_published_publication_by_slug(project.slug)

    cc_options =
      Oli.Authoring.Course.CreativeCommons.cc_options()
      |> Enum.map(fn {k, v} -> {v.text, k} end)
      |> Enum.sort(:desc)

    changeset = Project.changeset(project)

    socket =
      assign(socket,
        ctx: ctx,
        breadcrumbs: [Breadcrumb.new(%{full_title: "Project Overview"})],
        active: :overview,
        collaborators: Accounts.project_authors(project),
        activities_enabled: Activities.advanced_activities(project, is_admin?),
        can_enable_experiments: is_admin? and Oli.Delivery.Experiments.experiments_enabled?(),
        is_admin: is_admin?,
        changeset: changeset,
        form: to_form(changeset),
        latest_published_publication: latest_published_publication,
        publishers: Inventories.list_publishers(),
        title: "Overview | " <> project.title,
        attributes: project.attributes,
        language_codes: Oli.LanguageCodesIso639.codes(),
        license_opts: cc_options,
        collab_space_config: collab_space_config,
        revision_slug: revision_slug,
        latest_publication: latest_publication,
        notes_config: %{}
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="overview container mx-auto">
      <.form for={@form} phx-submit="update">
        <Overview.section
          title="Details"
          description="Your project title and description will be shown to students when you publish this project."
        >
          <div class="form-label-group mb-3">
            <%= label(@form, :title, "Project ID", class: "control-label") %>
            <%= text_input(@form, :slug, class: "form-control", disabled: true) %>
          </div>
          <div class="form-label-group mb-3">
            <%= label(@form, :title, "Project Title", class: "control-label") %>
            <%= text_input(@form, :title,
              class: "form-control",
              placeholder: "The title of your project...",
              required: false
            ) %>
          </div>
          <div class="form-label-group mb-3">
            <%= label(@form, :description, "Project Description", class: "control-label") %>
            <%= textarea(@form, :description,
              class: "form-control",
              placeholder: "A brief description of your project...",
              required: false
            ) %>
          </div>
          <.welcome_message_editor form={@form} project_slug={@project.slug} ctx={@ctx} />
          <div class="form-label-group mb-3">
            <%= label(@form, :description, "Latest Publication", class: "control-label") %>
            <%= case @latest_published_publication do %>
              <% %{edition: edition, major: major, minor: minor} -> %>
                <p class="text-secondary">
                  <%= OliWeb.Common.Utils.render_version(edition, major, minor) %>
                </p>
              <% _ -> %>
                <p class="text-secondary">This project has not been published</p>
            <% end %>
          </div>
          <div class="form-label-group mb-3">
            <%= label(@form, :publisher_id, "Project Publisher", class: "control-label") %>
            <%= select(@form, :publisher_id, Enum.map(@publishers, &{&1.name, &1.id}),
              class: "form-control",
              required: true
            ) %>
          </div>

          <div class="form-label-group mb-3">
            <%= if @can_enable_experiments do %>
              <div class="form-label-group mb-3 form-check">
                <%= checkbox(@form, :has_experiments, required: false) %>
                <%= label(@form, :has_experiments, "Enable Upgrade-based Experiments") %>
              </div>
            <% end %>

            <%= if @project.has_experiments do %>
              <a
                type="button"
                class="btn btn-link pl-0"
                href={
                  Routes.live_path(
                    OliWeb.Endpoint,
                    OliWeb.Experiments.ExperimentsView,
                    @project.slug
                  )
                }
              >
                Manage Experiments
              </a>
            <% end %>
          </div>

          <%= submit("Save", class: "btn btn-md btn-primary mt-2") %>
        </Overview.section>
        <Overview.section
          title="Project Attributes"
          description="Project wide configuration, not all options may be relevant for all subject areas."
        >
          <div class="d-block">
            <%= inputs_for @form, :attributes, fn fp -> %>
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
              <a
                type="button"
                class="btn btn-link pl-0"
                href={
                  Routes.live_path(
                    OliWeb.Endpoint,
                    OliWeb.Resources.AlternativesEditor,
                    @project.slug
                  )
                }
              >
                Manage Alternatives
              </a>
            </div>
            <small>
              Alternatives define the different flavors of content which can be authored. Students can then select which alternative they prefer to use.
            </small>
          </div>
        </Overview.section>

        <%= if @is_admin do %>
          <Overview.section title="Content Types" description="Enable optional content types.">
            <div class="form-label-group mb-3 form-check">
              <%= checkbox(@form, :allow_ecl_content_type, required: false) %>
              <%= label(@form, :allow_ecl_content_type, "ECL Code Editor",
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
          <div class="d-flex align-items-center">
            <div>
              <%= button("Bulk Resource Attribute Edit",
                to: Routes.ingest_path(@socket, :index_csv, @project.slug),
                method: :get,
                class: "btn btn-link action-button"
              ) %>
            </div>
            <span>Imports a <code>.csv</code> file to set new attributes.</span>
          </div>
        <% end %>

        <div class="d-flex align-items-center">
          <div>
            <%= button("Duplicate",
              to: Routes.project_path(@socket, :clone_project, @project),
              method: :post,
              class: "btn btn-link action-button",
              data_confirm: "Are you sure you want to duplicate this project?"
            ) %>
          </div>
          <span>Create a complete copy of this project.</span>
        </div>

        <div class="d-flex align-items-center">
          <%= button("Export",
            to: Routes.project_path(@socket, :download_export, @project),
            method: :post,
            class: "btn btn-link action-button"
          ) %>
          <span>Download this project and its contents.</span>
        </div>

        <div :if={@is_admin} class="d-flex align-items-center">
          <%= case @latest_publication do %>
            <% nil -> %>
              <.button variant={:link} disabled>Datashop Analytics</.button>
              <span>
                Project must be published to create a <.datashop_link /> snapshot for download
              </span>
            <% _pub -> %>
              <.button
                class="btn btn-link action-button"
                href={~p"/project/#{@project.slug}/datashop"}
              >
                Datashop Analytics
              </.button>
              <span>Create a <.datashop_link /> snapshot for download</span>
          <% end %>
        </div>

        <div class="d-flex align-items-center">
          <button
            type="button"
            class="btn btn-link text-danger action-button"
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

  def handle_event("on_selected", %{"project" => project_attrs}, socket) do
    project = socket.assigns.project
    changeset = Project.changeset(project, project_attrs)
    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("update", %{"project" => project_params}, socket) do
    project_params =
      if project_params["license"] == "custom",
        do: project_params,
        else: Map.put(project_params, "custom_license_details", nil)

    project_params =
      project_params
      |> add_custom_license_details()
      |> decode_welcome_title()

    project = socket.assigns.project

    socket =
      case Course.update_project(project, project_params) do
        {:ok, project} ->
          changeset = Project.changeset(project)

          socket
          |> assign(:project, project)
          |> assign(:changeset, changeset)
          |> assign(:form, to_form(changeset))
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
         push_redirect(socket,
           to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
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

    {:noreply, assign(socket, changeset: changeset, form: to_form(changeset))}
  end

  defp add_custom_license_details(%{"license" => "custom"} = project_params), do: project_params

  defp add_custom_license_details(project_params),
    do: Map.put(project_params, "custom_license_details", nil)

  defp decode_welcome_title(%{"welcome_title" => nil} = project_params), do: project_params

  defp decode_welcome_title(project_params),
    do: Map.update(project_params, "welcome_title", nil, &Poison.decode!(&1))

  defp datashop_link(assigns) do
    ~H"""
    <a class="text-primary external" href="https://pslcdatashop.web.cmu.edu/" target="_blank">
      datashop
    </a>
    """
  end

  attr :form, :any, required: true
  attr :project_slug, :string, required: true
  attr :ctx, :map, required: true

  defp welcome_message_editor(assigns) do
    ~H"""
    <% welcome_title =
      (fetch_field(@form.source, :welcome_title) &&
         fetch_field(@form.source, :welcome_title)["children"]) || [] %>
    <div id="welcome_title_field" class="form-label-group mb-3">
      <%= label(@form, :welcome_title, "Welcome Message Title", class: "control-label") %>
      <%= hidden_input(@form, :welcome_title) %>

      <div id="welcome_title_editor" phx-update="ignore">
        <%= React.component(
          @ctx,
          "Components.RichTextEditor",
          %{
            projectSlug: @project_slug,
            onEdit: "initial_function_that_will_be_overwritten",
            onEditEvent: "welcome_title_change",
            onEditTarget: "#welcome_title_field",
            editMode: true,
            value: welcome_title,
            fixedToolbar: true,
            allowBlockElements: false
          },
          id: "rich_text_editor_react_component"
        ) %>
      </div>
    </div>
    """
  end
end
