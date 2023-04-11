defmodule OliWeb.Projects.OverviewLive do
  use OliWeb, :live_view
  import Phoenix.Component

  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Inventories
  alias Oli.Publishing
  alias OliWeb.Common.Breadcrumb
  alias Oli.Activities
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Collaboration
  alias OliWeb.Project.OverviewSection
  alias OliWeb.Projects.RequiredSurvey

  def mount(_params, _session, socket) do
    project = socket.assigns.project

    author = socket.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    latest_published_publication =
      Publishing.get_latest_published_publication_by_slug(project.slug)

    {collab_space_config, revision_slug} = get_collab_space_config_and_revision(project.slug)

    socket =
      assign(socket,
        breadcrumbs: [Breadcrumb.new(%{full_title: "Project Overview"})],
        active: :overview,
        collaborators: Accounts.project_authors(project),
        activities_enabled: Activities.advanced_activities(project, is_admin?),
        can_enable_experiments: is_admin? and Oli.Delivery.Experiments.experiments_enabled?(),
        changeset: Project.changeset(project),
        latest_published_publication: latest_published_publication,
        publishers: Inventories.list_publishers(),
        title: "Overview | " <> project.title,
        attributes: project.attributes,
        language_codes: Oli.LanguageCodesIso639.codes(),
        collab_space_config: collab_space_config,
        revision_slug: revision_slug
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="overview container mx-auto">
      <.form let={f} for={@changeset} phx-submit="update" >
        <OverviewSection.render title="Details" description="Your project title and description will be shown to students when you publish this project.">
          <div class="form-label-group mb-3">
            <%= label f, :title, "Project ID", class: "control-label" %>
            <%= text_input f, :slug, class: "form-control", disabled: true %>
          </div>
          <div class="form-label-group mb-3">
            <%= label f, :title, "Project Title", class: "control-label" %>
            <%= text_input f, :title, class: "form-control", placeholder: "The title of your project...", required: false %>
          </div>
          <div class="form-label-group mb-3">
            <%= label f, :description, "Project Description", class: "control-label" %>
            <%= textarea f, :description, class: "form-control", placeholder: "A brief description of your project...", required: false %>
          </div>
          <div class="form-label-group mb-3">
            <%= label f, :description, "Latest Publication", class: "control-label" %>
            <%= case @latest_published_publication do %>
              <% %{edition: edition, major: major, minor: minor} -> %>
                <p class="text-secondary"><%= OliWeb.Common.Utils.render_version(edition, major, minor) %></p>
              <% _ -> %>
                <p class="text-secondary">This project has not been published</p>
            <% end %>
          </div>
          <div class="form-label-group mb-3">
            <%= label f, :publisher_id, "Project Publisher", class: "control-label" %>
            <%= select f, :publisher_id, Enum.map(@publishers, &{&1.name, &1.id}), class: "form-control", required: true %>
          </div>
          <%= if @can_enable_experiments do %>
            <div class="form-label-group mb-3">
              <%= label f, :has_experiments, "Enable Upgrade-based Experiments", class: "control-label" %>
              <%= checkbox f, :has_experiments, class: "form-control w-50", required: false %>
              <%= if @project.has_experiments do %>
                <a type="button" class="btn btn-link pl-0" href={Routes.live_path(OliWeb.Endpoint, OliWeb.Experiments.ExperimentsView, @project.slug)}>Manage Experiments</a>
              <% end %>
            </div>
          <% end %>
          <%= submit "Save", class: "btn btn-md btn-primary mt-2" %>
        </OverviewSection.render>
        <OverviewSection.render title="Project Attributes" description="Project wide configuration, not all options may be relevant for all subject areas.">
          <div class="d-block">
            <%= inputs_for f, :attributes, fn fp -> %>
              <div class="form-label-group mb-3">
                <%= label fp, :learning_language, "Learning Language (optional)", class: "control-label" %>
                <%= select fp, :learning_language, @language_codes, class: "form-control", required: false,  prompt: "What language is being taught in this project?" %>
              </div>
            <% end %>
          </div>
          <div>
            <%= submit "Save", class: "btn btn-md btn-primary mt-2" %>
          </div>
          <div class="mt-5">
            <div><a type="button" class="btn btn-link pl-0" href={Routes.live_path(OliWeb.Endpoint, OliWeb.Resources.AlternativesEditor, @project.slug)}>Manage Alternatives</a></div>
            <small>Alternatives define the different flavors of content which can be authored. Students can then select which alternative they prefer to use.</small>
          </div>
        </OverviewSection.render>
      </.form>

      <OverviewSection.render title="Project Labels" description="Project wide customization of labels.">
        <%= live_render @socket, OliWeb.Projects.CustomizationLive, id: "project_customizations", session: %{ "project_slug" => @project.slug } %>
      </OverviewSection.render>

      <OverviewSection.render title="Collaborators" description="Invite other authors by email to contribute to your project. Specify multiple separated by a comma.">
        <script src="https://createwww.google.com/recaptcha/api.js"></script>
        <.form let={f} for={:form} id="form-add-collaborator">
          <div class="form-group">
            <div class="input-group mb-3">
              <%= text_input f,
                  :collaborator_emails,
                  class: "form-control" <> error_class(f, :title, "is-invalid"),
                  placeholder: "collaborator@example.edu",
                  id: "input-title",
                  required: true,
                  autocomplete: "off",
                  autofocus: focusHelper(f, :collaborator_emails, default: false) %>
              <%= error_tag f, :collaborator_emails %>
              <div class="input-group-append">
                <%= submit "Send Invite",
                  id: "button-create-collaborator",
                  class: "btn btn-outline-primary",
                  phx_disable_with: "Adding Collaborator...",
                  form: f.id %>
              </div>
            </div>
            <div class="input-group mb-3">
              <div class="g-recaptcha" data-sitekey={Application.fetch_env!(:oli, :recaptcha)[:site_key]} />
            </div>
            <%= error_tag f, :captcha %>
          </div>
        </.form>
        <%= render_many @collaborators, OliWeb.ProjectView, "_collaborator.html", %{conn: @socket, as: :collaborator, project: @project} %>
      </OverviewSection.render>

      <OverviewSection.render title="Advanced Activities" description="Enable advanced activity types for your project to include in your curriculum.">
        <%= render_many @activities_enabled, OliWeb.ProjectView, "_tr_activities_available.html", %{conn: @socket, as: :activity_enabled, project: @project} %>
      </OverviewSection.render>

      <%= live_render @socket, OliWeb.Projects.VisibilityLive, id: "project_visibility", session: %{ "project_slug" => @project.slug } %>

      <OverviewSection.render title="Collaboration Space" description="Allows to activate and configure a collaborative space for the root resource of a project.">
        <div class="container mx-auto">
          <%=
            live_render(@socket, OliWeb.CollaborationLive.CollabSpaceConfigView, id: "project_collab_space_config",
              session: %{
                "collab_space_config" => @collab_space_config,
                "project_slug" => @project.slug,
                "resource_slug" => @revision_slug,
                "is_overview_render" => true,
              })
          %>
        </div>
      </OverviewSection.render>

      <OverviewSection.render title="Required Survey" description="Allows to activate and configure a survey for all students that enter the course for the first time.">
        <.live_component module={RequiredSurvey} id="required-survey-section" project={@project} author_id={@current_author.id} enabled={@project.required_survey_resource_id} />
      </OverviewSection.render>

      <OverviewSection.render title="Actions" is_last={true}>
        <div class="d-flex align-items-center">
          <div>
            <%= button("Duplicate",
              to: Routes.project_path(@socket, :clone_project, @project),
              method: :post,
              class: "btn btn-link action-button",
              data_confirm: "Are you sure you want to duplicate this project?")
            %>
          </div>
          <span>Create a complete copy of this project.</span>
        </div>

        <div class="d-flex align-items-center">
          <%= button("Export", to: Routes.project_path(@socket, :download_export, @project), method: :post, class: "btn btn-link action-button") %>
          <span>Download this project and its contents.</span>
        </div>

        <div class="d-flex align-items-center">
          <%= case Oli.Publishing.get_latest_published_publication_by_slug(@project.slug) do %>
            <% nil -> %>
              <button disabled class="btn btn-link action-button">
                <span data-bs-toggle="tooltip" data-bs-placement="top" title="Project must be published to generate a datashop export file.">Download</span>
              </button>
            <% _pub -> %>
              <%= button("Download", to: Routes.project_path(@socket, :download_datashop, @project), method: :post, class: "btn btn-link action-button") %>
          <% end %>
          <span>Download a <a class="text-primary" href="https://pslcdatashop.web.cmu.edu/" target="_blank">Datashop</a> file.</span>
        </div>

        <div class="d-flex align-items-center">
          <button type="button" class="btn btn-link text-danger action-button" onclick="OLI.showModal('delete-package-modal')">Delete</button>
          <span>Permanently delete this project.</span>
        </div>
      </OverviewSection.render>
    </div>

    <div class="modal fade" id="delete-package-modal" tabindex="-1" role="dialog" aria-labelledby="delete-modal" aria-hidden="true">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Are you absolutely sure?</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div class="container form-container">
              <div class="mb-3">This action will not affect existing course sections that are using this project.
                Those sections will continue to operate as intended
              </div>
              <div>
                <p>Please type <strong><%= @project.title %></strong> below to confirm.</p>
              </div>
              <.form let={f} for={:form} phx-submit="delete">
                <div class="mt-2">
                  <%= text_input f, :title, class: "form-control", id: "delete-confirm-title", required: true %>
                </div>
                <div class="d-flex">
                  <button id="delete-modal-submit" type="submit" class="btn btn-outline-danger mt-2 flex-fill" disabled>Delete this course</button>
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

  defp get_collab_space_config_and_revision(project_slug) do
    %{slug: revision_slug} = AuthoringResolver.root_container(project_slug)

    {:ok, collab_space_config} =
      Collaboration.get_collab_space_config_for_page_in_project(
        revision_slug,
        project_slug
      )

    {collab_space_config, revision_slug}
  end

  def handle_event("update", %{"project" => project_params}, socket) do
    project = socket.assigns.project

    socket =
      case Course.update_project(project, project_params) do
        {:ok, project} ->
          socket
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
         push_redirect(socket, to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:changeset, changeset)
          |> put_flash(:error, "Project could not be deleted.")

        {:noreply, socket}
    end
  end
end
