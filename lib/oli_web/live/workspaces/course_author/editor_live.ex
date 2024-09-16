defmodule OliWeb.Workspaces.CourseAuthor.EditorLive do
  use OliWeb, :live_view
  use Phoenix.HTML

  import OliWeb.ProjectPlugs
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.Common.Breadcrumb
  alias Oli.PartComponents
  alias Oli.Delivery.Hierarchy
  alias Oli.Resources.ResourceType
  alias OliWeb.Components.Delivery.AdaptiveIFrame
  alias OliWeb.Common.React

  @impl true
  def mount(%{"project_id" => project_slug, "revision_slug" => revision_slug}, _session, socket) do
    author = socket.assigns[:current_author]
    project = socket.assigns.project
    is_admin? = Accounts.at_least_content_admin?(author)

    case PageEditor.create_context(project_slug, revision_slug, author) do
      {:ok, context} ->
        context = Map.put(context, :hasExperiments, project.has_experiments)

        breadcrumbs =
          Breadcrumb.trail_to(
            project_slug,
            revision_slug,
            AuthoringResolver,
            project.customizations
          )

        # Set initial state in the socket
        {:ok,
         assign(socket,
           active: :curriculum,
           breadcrumbs: breadcrumbs,
           is_admin?: is_admin?,
           raw_context: context,
           scripts: Activities.get_activity_scripts(:authoring_script),
           part_scripts: PartComponents.get_part_component_scripts(:authoring_script),
           project_slug: project_slug,
           revision_slug: revision_slug,
           activity_types: Activities.activities_for_project(project),
           part_component_types: PartComponents.part_components_for_project(project),
           graded: context.graded,
           title: "Edit | " <> context.title,
           collab_space_config: context.collab_space_config
         )}

      {:error, :not_found} ->
        # In case of not found, we can redirect or handle error accordingly
        {:ok,
         socket
         |> put_flash(:error, "Not Found")
         |> assign(
           breadcrumbs: [
             Breadcrumb.curriculum(project_slug),
             Breadcrumb.new(%{full_title: "Not Found"})
           ],
           title: "Not Found"
         )
         |> push_redirect(to: Routes.shared_path(socket, :not_found))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/pageeditor.js")}>
    </script>
    <%= for script <- @scripts do %>
      <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/#{script}")}>
      </script>
    <% end %>

    <%= render(OliWeb.SharedView, "_admin_edit_banner.html", %{
      is_admin?: @is_admin?,
      project_slug: @project_slug,
      revision_slug: @revision_slug
    }) %>

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
end
