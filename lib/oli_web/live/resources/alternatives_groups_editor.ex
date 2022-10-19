defmodule OliWeb.Resources.AlternativesGroupsEditor do
  use OliWeb, :live_view

  alias Oli.Resources
  alias Oli.Resources.{Revision, ResourceType}
  alias Oli.Authoring.Broadcaster.Subscriber
  alias OliWeb.Common.{Breadcrumb, SessionContext}
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Authoring.Course

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
       subscriptions: subscriptions,
       changeset: Resources.change_revision(%Revision{})
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
      Alternatives Groups Editor
    """
  end

  # spin up subscriptions for the alternatives resources
  defp subscribe(alternatives_groups, project_slug) do
    ids = Enum.map(alternatives_groups, fn p -> p.resource.id end)
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
end
