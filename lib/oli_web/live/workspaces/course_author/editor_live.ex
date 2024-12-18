defmodule OliWeb.Workspaces.CourseAuthor.Curriculum.EditorLive do
  use OliWeb, :live_view
  use Phoenix.HTML

  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.PartComponents
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.React
  alias OliWeb.Workspaces.CourseAuthor.HistoryLive

  @impl true
  def mount(%{"project_id" => project_slug, "revision_slug" => revision_slug}, _session, socket) do
    author = socket.assigns[:current_author]
    project = socket.assigns.project
    is_admin? = Accounts.at_least_content_admin?(author)

    case PageEditor.create_context(project_slug, revision_slug, author) do
      {:ok, context} ->
        live_edit(socket, project, context, project_slug, revision_slug, is_admin?)

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Revision not found")
         |> push_navigate(to: ~p"/workspaces/course_author")}
    end
  end

  @impl true
  def render(%{app_params: _app_params} = assigns) do
    ~H"""
    <div id="eventIntercept" phx-hook="LoadSurveyScripts"></div>
    <%= if connected?(@socket) and assigns[:maybe_scripts_loaded] do %>
      <.maybe_show_error error={@error} />
      <div id="editor" class="container">
        <%= React.component(@ctx, "Components.Authoring", @app_params, id: "authoring_editor") %>
      </div>
      <%= render_prev_next_nav(assigns) %>
    <% else %>
      <.loader />
    <% end %>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="eventIntercept" phx-hook="LoadSurveyScripts"></div>
    <%= if connected?(@socket) and assigns[:maybe_scripts_loaded] do %>
      <.maybe_show_error error={@error} />
      <%= if @is_admin? do %>
        <div
          class="alert alert-warning alert-dismissible flex flex-row fade show container mt-2 mx-auto"
          role="alert"
        >
          <div class="flex-1">
            <strong>You are editing as an administrator</strong>
          </div>

          <div>
            <%= link class: "toolbar-link", to: Routes.live_path(OliWeb.Endpoint, HistoryLive, @project_slug, @revision_slug) do %>
              <span style="margin-right: 5px"><i class="fas fa-history"></i></span><span>View History</span>
            <% end %>
          </div>

          <button type="button" class="close ml-4" data-bs-dismiss="alert" aria-label="Close">
            <i class="fa-solid fa-xmark fa-lg"></i>
          </button>
        </div>
      <% end %>

      <div id="editor" style="width: 95%;" class="container mx-auto">
        <%= React.component(@ctx, "Components.PageEditor", @raw_context, id: "page_editor") %>
      </div>

      <div class="container mx-auto mt-5">
        <%= live_render(@socket, OliWeb.CollaborationLive.CollabSpaceConfigView,
          id: "collab-space-#{@project_slug}-#{@revision_slug}",
          session: %{
            "collab_space_config" => @collab_space_config,
            "project_slug" => @project_slug,
            "resource_slug" => @revision_slug
          }
        ) %>
      </div>

      <%= render_prev_next_nav(assigns) %>
    <% else %>
      <.loader />
    <% end %>
    """
  end

  @impl true
  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, assign(socket, error: true, maybe_scripts_loaded: true)}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, maybe_scripts_loaded: true)}
  end

  defp maybe_show_error(assigns) do
    ~H"""
    <div :if={@error} class="alert alert-danger m-0 flex flex-row justify-between w-full" role="alert">
      Something went wrong when loading the JS dependencies.
    </div>
    """
  end

  defp live_edit(socket, project, context, project_slug, revision_slug, is_admin?) do
    context = Map.put(context, :hasExperiments, project.has_experiments)
    activity_types = Activities.activities_for_project(project)
    part_component_types = PartComponents.part_components_for_project(project)

    breadcrumbs =
      Breadcrumb.trail_to(project_slug, revision_slug, AuthoringResolver, project.customizations)

    content = %{
      active: :curriculum,
      activity_types: activity_types,
      breadcrumbs: breadcrumbs,
      collab_space_config: context.collab_space_config,
      graded: context.graded,
      is_admin?: is_admin?,
      part_component_types: part_component_types,
      part_scripts: PartComponents.get_part_component_scripts(),
      project_slug: project_slug,
      context: context,
      raw_context: context,
      revision_slug: revision_slug,
      scripts: Activities.get_activity_scripts(),
      title: "Edit | " <> context.title,
      resource_title: project.title,
      resource_slug: project.slug
    }

    {content, target_scripts} =
      case context do
        %{content: %{"advancedAuthoring" => true}} ->
          activity_type_scripts =
            Enum.reduce(activity_types, [], fn %{slug: slug, authoring_script: authoring_script},
                                               acc ->
              if slug == "oli_adaptive", do: [authoring_script | acc], else: acc
            end)

          updated_content =
            Map.put(content, :app_params, %{
              isAdmin: is_admin?,
              revisionSlug: revision_slug,
              projectSlug: project_slug,
              graded: context.graded,
              content: context,
              paths: %{images: Routes.static_path(socket, "/images")},
              activityTypes: activity_types,
              partComponentTypes: part_component_types,
              appsignalKey: Application.get_env(:appsignal, :client_key),
              initialSidebarExpanded: socket.assigns[:sidebar_expanded]
            })

          {updated_content, ["authoring.js"] ++ activity_type_scripts}

        _ ->
          {content, ["pageeditor.js"]}
      end

    all_scripts = content.part_scripts ++ content.scripts ++ target_scripts
    all_scripts = all_scripts |> Enum.uniq() |> Enum.map(&"/js/#{&1}")

    socket =
      socket
      |> assign(maybe_scripts_loaded: false)
      |> push_event("load_survey_scripts", %{script_sources: all_scripts})

    {:ok, assign(socket, content)}
  end

  defp render_prev_next_nav(assigns) do
    ~H"""
    <nav class="previous-next-nav d-flex flex-row" aria-label="Page navigation">
      <%= if @context.previous_page do %>
        <.link
          class="page-nav-link btn"
          navigate={
            ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@context.previous_page["slug"]}/edit"
          }
        >
          <div class="flex items-center justify-between">
            <div class="mr-4">
              <i class="fas fa-arrow-left nav-icon"></i>
            </div>
            <div class="flex flex-col text-right overflow-hidden">
              <div class="nav-label"><%= "Previous" %></div>
              <div class="nav-title"><%= @context.previous_page["title"] %></div>
            </div>
          </div>
        </.link>
      <% else %>
        <div class="page-nav-link-placeholder"></div>
      <% end %>

      <div class="flex-grow-1"></div>

      <%= if @context.next_page do %>
        <.link
          class="page-nav-link btn"
          navigate={
            ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@context.next_page["slug"]}/edit"
          }
        >
          <div class="flex items-center justify-between">
            <div class="flex flex-col text-left overflow-hidden">
              <div class="nav-label"><%= "Next" %></div>
              <div class="nav-title"><%= @context.next_page["title"] %></div>
            </div>
            <div class="ml-4">
              <i class="fas fa-arrow-right nav-icon"></i>
            </div>
          </div>
        </.link>
      <% else %>
        <div class="page-nav-link-placeholder"></div>
      <% end %>
    </nav>
    """
  end
end
