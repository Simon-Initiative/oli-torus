defmodule OliWeb.Resources.AlternativesGroupsEditor do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.Resources
  alias Oli.Resources.{Revision, ResourceType}
  alias Oli.Authoring.Broadcaster.Subscriber
  alias OliWeb.Common.{Breadcrumb, SessionContext}
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Authoring.Course
  alias OliWeb.Objectives.CreateGroupModal

  @impl Phoenix.LiveView
  def mount(%{"project_id" => project_slug}, session, socket) do
    context = SessionContext.init(session)
    project = Course.get_project_by_slug(project_slug)

    {:ok, alternatives_groups} =
      ResourceEditor.list(
        project.slug,
        context.author,
        ResourceType.get_id_by_type("alternatives_group")
      )

    subscriptions = subscribe(alternatives_groups, project.slug)

    {:ok,
     assign(socket,
       context: context,
       project: project,
       author: context.author,
       title: "Alternatives Groups | " <> project.title,
       breadcrumbs: [Breadcrumb.new(%{full_title: "Alternatives Groups"})],
       alternatives_groups: alternatives_groups,
       subscriptions: subscriptions
     )}
  end

  @impl Phoenix.LiveView
  def terminate(_reason, socket) do
    %{project: project, subscriptions: subscriptions} = socket.assigns

    unsubscribe(subscriptions, project.slug)
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <%= render_modal(assigns) %>

      <div class="alternatives-groups container">
        <h2>Alternatives Groups</h2>
        <div class="d-flex flex-row">
          <div class="flex-grow-1"></div>
          <button class="btn btn-primary" phx-click="show_create_modal"><i class="fa fa-plus"></i> New Group</button>
        </div>
        <div class="d-flex flex-column my-4">
        <%= if Enum.count(@alternatives_groups) > 0 do %>
          <ul class="list-group">
            <%= for group <- @alternatives_groups do %>
              <.group group={group} />
            <% end %>
          </ul>
        <% else %>
          <div class="text-center">There are no alternatives groups</div>
        <% end %>
          </div>
      </div>
    """
  end

  def group(assigns) do
    ~H"""
      <div class="group">
        <li class="list-group-item d-flex flex-row align-items-center">
          <div><%= @group.title %></div>
          <div class="flex-grow-1"></div>
          <button class="btn btn-danger btn-sm mr-2" phx-click="delete" phx-value-resource_id={@group.resource_id}>Delete</button>
        </li>
      </div>
    """
  end

  # spin up subscriptions for the alternatives resources
  defp subscribe(alternatives_groups, project_slug) do
    ids = Enum.map(alternatives_groups, fn p -> p.resource_id end)
    Enum.each(ids, &Subscriber.subscribe_to_new_revisions_in_project(&1, project_slug))

    Subscriber.subscribe_to_new_resources_of_type(
      ResourceType.get_id_by_type("alternatives_group"),
      project_slug
    )

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, project_slug) do
    Subscriber.unsubscribe_to_new_resources_of_type(
      ResourceType.get_id_by_type("alternatives_group"),
      project_slug
    )

    Enum.each(ids, &Subscriber.unsubscribe_to_new_revisions_in_project(&1, project_slug))
  end

  def handle_event("show_create_modal", _, socket) do
    changeset =
      {%{}, %{name: :string}}
      |> Ecto.Changeset.cast(%{}, [:name])

    modal = %{
      component: CreateGroupModal,
      assigns: %{
        id: "create",
        changeset: changeset
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event("validate-create", %{"group_params" => %{"name" => _}}, socket) do
    {:noreply, socket}
  end

  def handle_event("create", %{"group_params" => %{"name" => name}}, socket) do
    %{project: project, author: author, alternatives_groups: alternatives_groups} = socket.assigns

    {:ok, group} =
      ResourceEditor.create(
        project.slug,
        author,
        ResourceType.get_id_by_type("alternatives_group"),
        %{title: name, content: %{options: []}}
      )

    {:noreply, hide_modal(socket) |> assign(alternatives_groups: [group | alternatives_groups])}
  end

  def handle_event("delete", %{"resource_id" => resource_id}, socket) do
    %{project: project, author: author, alternatives_groups: alternatives_groups} = socket.assigns

    {:ok, deleted} = ResourceEditor.delete(project.slug, resource_id, author)

    {:noreply,
     assign(socket,
       alternatives_groups:
         Enum.filter(alternatives_groups, fn r -> r.resource_id != deleted.resource_id end)
     )}
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, hide_modal(socket)}
  end
end
