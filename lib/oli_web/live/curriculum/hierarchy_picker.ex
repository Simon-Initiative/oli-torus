defmodule OliWeb.Curriculum.HierarchyPicker do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Common.Breadcrumb
  alias Oli.Resources.Numbering
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Editing.ContainerEditor

  def update(assigns, socket) do
    %{project: project, container: container} = assigns

    {:ok,
      assign(socket,
        project: project,
        container: container,
        breadcrumbs: Breadcrumb.trail_to(project.slug, container.slug),
        children: ContainerEditor.list_all_container_children(container, project),
        selected: nil,
        numberings: Numbering.number_full_tree(AuthoringResolver, project.slug)
      )}
  end

  def render(%{children: children} = assigns) do
    ~L"""
    <div id="hierarchy-picker" class="hierarchy-picker">
      <div class="hierarchy-navigation">
        <%= render_breadcrumb assigns %>
      </div>
      <div class="hierarchy">
        <%= for child <- children |> Enum.sort(&sort_containers_first/2) do %>

          <div id="hierarchy_item_<%= child.resource_id %>"
            phx-click="select"
            phx-value-slug="<%= child.slug %>">
            <div class="flex-1">
              <%= OliWeb.Curriculum.EntryLive.icon(%{child: child}) %>
              <%= resource_link assigns, child %>
            </div>
          </div>

        <% end %>
      </div>
    </div>
    """
  end

  def render_breadcrumb(%{breadcrumbs: breadcrumbs} = assigns) do
    ~L"""
      <ol class="breadcrumb custom-breadcrumb p-1 px-2">
        <%= if length(breadcrumbs) > 1 do %>
          <button class="btn btn-sm text-primary"><i class="las la-arrow-left"></i></button>
        <% end %>

        <%= for breadcrumb <- breadcrumbs do %>
          <%= render_breadcrumb_item Enum.into(%{
            breadcrumb: breadcrumb,
            show_short: length(breadcrumbs) > 3
           }, assigns) %>
        <% end %>
      </ol>
    """
  end

  defp render_breadcrumb_item(%{breadcrumb: breadcrumb, show_short: show_short} = assigns) do
    ~L"""
    <li class="breadcrumb-item align-self-center" phx-click="select" phx-value-slug="<%= breadcrumb.slug %>" phx-target="<%= @myself %>">
      <%= get_title(breadcrumb, show_short) %>
    </li>
    """
  end

  defp get_title(breadcrumb, true = _show_short), do: breadcrumb.short_title
  defp get_title(breadcrumb, false = _show_short), do: breadcrumb.full_title

  defp resource_link(%{numberings: numberings} = assigns, revision) do
    with resource_type <- Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
      case resource_type do
        "container" ->
          numbering = Map.get(numberings, revision.id)

          title =
            if numbering do
              Numbering.prefix(numbering) <> ": " <> revision.title
            else
              revision.title
            end

          ~L"""
            <button class="btn btn-link ml-1 mr-1 entry-title" phx-click="select" phx-value-slug="<%= revision.slug %>" phx-target="<%= @myself %>">
              <%= title %>
            </button>
          """

        _ ->
          ~L"""
            <button class="btn btn-link ml-1 mr-1 entry-title" disabled><%= revision.title %></button>
          """
      end
    end
  end

  defp sort_containers_first(a, b) do
    case {
      Oli.Resources.ResourceType.get_type_by_id(a.resource_type_id),
      Oli.Resources.ResourceType.get_type_by_id(b.resource_type_id)
    } do
      {"container", "container"} -> true
      {"container", _} -> true
      _ -> false
    end
  end

  def handle_event("select", %{"slug" => slug}, socket) do
    %{project: project} = socket.assigns
    container = AuthoringResolver.from_revision_slug(project.slug, slug)
    children = ContainerEditor.list_all_container_children(container, project)
    breadcrumbs = Breadcrumb.trail_to(project.slug, container.slug)

    {:noreply, assign(socket, container: container, children: children, breadcrumbs: breadcrumbs)}
  end

end
