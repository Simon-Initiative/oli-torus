defmodule OliWeb.Workspaces.CourseAuthor.EditorLive do
  use OliWeb, :live_view
  use Phoenix.HTML

  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.PartComponents
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.React

  @impl true
  def mount(%{"project_id" => project_slug, "revision_slug" => revision_slug}, _session, socket) do
    author = socket.assigns[:current_author]
    project = socket.assigns.project
    is_admin? = Accounts.at_least_content_admin?(author)

    case PageEditor.create_context(project_slug, revision_slug, author) do
      {:ok, context} ->
        live_edit(socket, project, context, project_slug, revision_slug, is_admin?)

      {:error, :not_found} ->
        OliWeb.ResourceController.render_not_found(OliWeb.Endpoint, project_slug)
    end
  end

  @impl true
  def render(assigns) do
    if assigns[:app_params], do: render_advanced(assigns), else: render_basic(assigns)
  end

  defp render_basic(assigns) do
    ~H"""
    <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/pageeditor.js")}>
    </script>
    <%= for script <- @scripts do %>
      <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/#{script}")}>
      </script>
    <% end %>

    <%= if @is_admin? do %>
      <div
        class="alert alert-warning alert-dismissible flex flex-row fade show container mt-2 mx-auto"
        role="alert"
      >
        <div class="flex-1">
          <strong>You are editing as an administrator</strong>
        </div>

        <div>
          <%= link class: "toolbar-link", to: Routes.live_path(OliWeb.Endpoint, OliWeb.RevisionHistory, @project_slug,@revision_slug) do %>
            <span style="margin-right: 5px"><i class="fas fa-history"></i></span><span>View History</span>
          <% end %>
        </div>

        <button type="button" class="close ml-4" data-bs-dismiss="alert" aria-label="Close">
          <i class="fa-solid fa-xmark fa-lg"></i>
        </button>
      </div>
    <% end %>

    <div id="editor" class="container mx-auto">
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
    """

    # TODO: Adding this component crashes the liveview.
    # <%= render(OliWeb.ResourceView, "_preview_previous_next_nav.html", %{
    #   context: @raw_context,
    #   action: :edit
    # }) %>
  end

  defp render_advanced(assigns) do
    ~H"""
    <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/authoring.js")}>
    </script>

    <%= for %{slug: slug, authoring_script: script} <- @activity_types do %>
      <%= if slug == "oli_adaptive" do %>
        <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/#{script}")}>
        </script>
      <% end %>
    <% end %>

    <%= for script <- @part_scripts do %>
      <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/#{script}")}>
      </script>
    <% end %>

    <div id="editor" class="container">
      <%= React.component(@ctx, "Components.Authoring", @app_params, id: "authoring_editor") %>
    </div>
    """

    # TODO: Adding this component crashes the liveview.
    # <%= render(OliWeb.ResourceView, "_preview_previous_next_nav.html", %{
    #   context: @raw_context,
    #   action: :edit
    # }) %>
  end

  defp live_edit(socket, project, context, project_slug, revision_slug, is_admin?) do
    context = Map.put(context, :hasExperiments, project.has_experiments)
    activity_types = Activities.activities_for_project(project)
    part_component_types = PartComponents.part_components_for_project(project)

    content = %{
      active: :curriculum,
      activity_types: activity_types,
      breadcrumbs:
        Breadcrumb.trail_to(
          project_slug,
          revision_slug,
          Oli.Publishing.AuthoringResolver,
          project.customizations
        ),
      collab_space_config: context.collab_space_config,
      graded: context.graded,
      is_admin?: is_admin?,
      part_component_types: part_component_types,
      part_scripts: PartComponents.get_part_component_scripts(:authoring_script),
      project_slug: project_slug,
      raw_context: context,
      revision_slug: revision_slug,
      scripts: Activities.get_activity_scripts(:authoring_script),
      title: "Edit | " <> context.title
    }

    content =
      case context do
        %{content: %{"advancedAuthoring" => true}} ->
          Map.put(content, :app_params, %{
            isAdmin: is_admin?,
            revisionSlug: revision_slug,
            projectSlug: project_slug,
            graded: context.graded,
            content: context,
            paths: %{
              images: Routes.static_path(socket, "/images")
            },
            activityTypes: activity_types,
            partComponentTypes: part_component_types,
            appsignalKey: Application.get_env(:appsignal, :client_key)
          })

        _ ->
          content
      end

    {:ok, assign(socket, content)}
  end
end
