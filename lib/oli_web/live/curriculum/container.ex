defmodule OliWeb.Curriculum.Container do

  @moduledoc """
  LiveView implementation of a container editor. Given that we only
  support one fixed top-level container this view ultimately is the
  entire Curriculum editor.  At some point in the future this implementation
  can be generalized a bit further to allow it to operate as an editor
  for any container - not just the root container.
  """

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}


  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Authoring.Course
  alias OliWeb.Curriculum.Entry
  alias OliWeb.Curriculum.DropTarget
  alias OliWeb.Curriculum.Settings
  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Accounts.Author
  alias Oli.Repo
  alias Phoenix.PubSub

  def mount(params, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(Map.get(params, "project_id"))
    pages = ContainerEditor.list_all_pages(project)

    root_resource = AuthoringResolver.root_resource(project.slug)

    page_activity_map = build_activity_to_page_map(pages)
    activity_map = build_activity_map(project.slug, page_activity_map)
    objective_map = build_objective_map(project.slug, activity_map)

    subscriptions = subscribe(root_resource, pages, activity_map, objective_map, project.slug)

    {:ok, assign(socket,
      pages: pages,
      active: :curriculum,
      title: "Curriculum",
      page_activity_map: page_activity_map,
      activity_map: activity_map,
      objective_map: objective_map,
      changeset: Resources.change_revision(%Revision{}),
      root_resource: root_resource,
      project: project,
      subscriptions: subscriptions,
      author: author,
      selected: nil)
    }
  end

  # creates a map of page resource ids to a list of the activity ids for the activities
  # that they contain
  defp build_activity_to_page_map(pages) do

    Enum.reduce(pages, %{}, fn %{resource_id: page_id, content: %{"model" => model}}, map ->
      activities = get_activities_from_page(model)
      Map.put(map, page_id, activities)
    end)

  end

  # extract all the activity ids referenced from a page model
  defp get_activities_from_page(nil), do: []
  defp get_activities_from_page(model) do
    Enum.filter(model, fn %{"type" => type} -> type == "activity-reference" end)
    |> Enum.map(fn %{"activity_id" => id} -> id end)
  end

  # creates a map of activity ids to activity revisions, based on the page_to_activities_map
  defp build_activity_map(project_slug, page_to_activities_map) do
    all_activities = Enum.map(page_to_activities_map, fn {_, activity_ids} -> activity_ids end)
    |> List.flatten()

    AuthoringResolver.from_resource_id(project_slug, all_activities)
    |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.resource_id, a) end)
  end

  # creates a map of objective ids to objective revisions, based on the activity map
  defp build_objective_map(project_slug, activity_map) do
    all_objectives = Enum.reduce(activity_map, [], fn {_, %{objectives: objectives}}, all ->
      (Enum.map(objectives, fn {_, ids} -> ids end) |> List.flatten()) ++ all
    end)

    AuthoringResolver.from_resource_id(project_slug, all_objectives)
    |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.resource_id, a) end)

  end

  def render(assigns) do
    ~L"""
      <div class="container container-editor">
        <div class="row">
          <div class="col-12">
            <nav aria-label="breadcrumb" class="mb-5">
              <ol class="breadcrumb">
                <li class="breadcrumb-item active" aria-current="page">Curriculum</li>
              </ol>
            </nav>
          </div>
        </div>
        <div class="row">
          <div class="col-12">
            <p class="text-secondary mb-3">
              Create and arrange items to form your project curriculum. Select an item to edit it.
            </p>
          </div>
        </div>
        <div class="row" phx-window-keydown="keydown">
          <div class="col-12 col-md-8">

            <div class="curriculum-entries">
              <%= for {page, index} <- Enum.with_index(@pages) do %>
                <%= live_component @socket, DropTarget, index: index %>
                <%= live_component @socket, Entry, selected: page == @selected,
                  page: page, activity_ids: Map.get(assigns.page_activity_map, page.resource_id),
                  activity_map: assigns.activity_map, objective_map: assigns.objective_map,
                  index: index, project: @project %>
              <% end %>
              <%= live_component @socket, DropTarget, index: length(@pages) %>
            </div>

            <div class="mt-5">
              Add new
              <button phx-click="add" phx-value-type="Unscored" class="btn btn-sm btn-outline-primary ml-2" type="button">
                Practice Page
              </button>
              <button phx-click="add" phx-value-type="Scored" class="btn btn-sm btn-outline-primary ml-2" type="button">
                Graded Assessment
              </button>
            </div>

          </div>

          <div class="col-12 col-md-4">
            <%= if @selected != nil do %>
            <%= live_component @socket, Settings, page: @selected, changeset: @changeset, project: @project %>
            <% end %>
          </div>
        </div>

      </div>
    """
  end

  # spin up subscriptions for the container and for all of its pages, activities and attached objectives
  defp subscribe(root_resource, pages, activity_map, objective_map, project_slug) do

    activity_ids = Enum.map(activity_map, fn {id, _} -> id end)
    objective_ids = Enum.map(objective_map, fn {id, _} -> id end)

    ids = [root_resource.resource_id] ++ Enum.map(pages, fn p -> p.resource_id end) ++ activity_ids ++ objective_ids
    Enum.each(ids, fn id -> PubSub.subscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)
    PubSub.subscribe(Oli.PubSub, "new_resource:resource_type:" <> Integer.to_string(Oli.Resources.ResourceType.get_id_by_type("objective")) <> ":project:" <> project_slug)

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, project_slug) do
    PubSub.unsubscribe(Oli.PubSub, "new_resource:resource_type:" <> Integer.to_string(Oli.Resources.ResourceType.get_id_by_type("objective")) <> ":project:" <> project_slug)
    Enum.each(ids, fn id -> PubSub.unsubscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)
  end

  # handle change of selection
  def handle_event("select", %{"slug" => slug}, socket) do
    selected = Enum.find(socket.assigns.pages, fn r -> r.slug == slug end)
    {:noreply, assign(socket, :selected, selected)}
  end

  # process form submission to save page settings
  def handle_event("save", params, socket) do

    params = Enum.reduce(params, %{}, fn {k, v}, m ->
      case MapSet.member?(MapSet.new(["_csrf_token", "_target"]), k) do
        true -> m
        false -> Map.put(m, String.to_existing_atom(k), v)
      end
    end)

    socket = case ContainerEditor.edit_page(socket.assigns.project, socket.assigns.selected.slug, params) do
      {:ok, _} -> socket
      {:error, _} -> socket
      |> put_flash(:error, "Could not edit page")
    end

    {:noreply, socket}
  end

  def handle_event("keydown", %{"key" => key, "shiftKey" => shiftKeyPressed?} = params, socket) do
    focused_index = case params["index"] do
      nil -> nil
      stringIndex -> String.to_integer(stringIndex)
    end
    last_index = length(socket.assigns.pages) - 1
    pages = socket.assigns.pages

    case {focused_index, key, shiftKeyPressed?} do
      {nil, _, _} -> {:noreply, socket}
      {^last_index, "ArrowDown", _} -> {:noreply, socket}
      {0, "ArrowUp", _} -> {:noreply, socket}
      # Each drop target has a corresponding entry after it with a matching index.
      # That means that the "drop index" is the index of where you'd like to place the item AHEAD OF
      # So to reorder an item below its current position, we add +2 ->
      # +1 would mean insert it BEFORE the next item, but +2 means insert it before the item after the next item.
      # See the logic in container editor that does the adjustment based on the positions of the drop targets.
      {focused_index, "ArrowDown", true} -> handle_event("reorder", %{"sourceIndex" => Integer.to_string(focused_index), "dropIndex" => Integer.to_string(focused_index + 2)}, socket)
      {focused_index, "ArrowUp", true} -> handle_event("reorder", %{"sourceIndex" => Integer.to_string(focused_index), "dropIndex" => Integer.to_string(focused_index - 1)}, socket)
      {focused_index, "Enter", _} -> {:noreply, assign(socket, :selected, Enum.at(pages, focused_index))}
      {_, _, _} -> {:noreply, socket}
    end

  end

  # handle reordering event
  def handle_event("reorder", %{"sourceIndex" => source_index, "dropIndex" => index}, socket) do
    source = Enum.at(socket.assigns.pages, String.to_integer(source_index))

    socket = case ContainerEditor.reorder_child(socket.assigns.project, socket.assigns.author, source.slug, String.to_integer(index)) do
      {:ok, _} -> socket
      {:error, _} -> socket
      |> put_flash(:error, "Could not edit page")
    end

    {:noreply, socket}
  end

  # handle processing deletion of currently selected item
  def handle_event("delete", _, socket) do

    socket = case ContainerEditor.remove_child(socket.assigns.project, socket.assigns.author, socket.assigns.selected.slug) do
      {:ok, _} -> socket
      {:error, _} -> socket
      |> put_flash(:error, "Could not remove page")
    end

    {:noreply, socket}
  end

  # handle clicking of the "Add Graded Assessment" or "Add Practice Page" buttons
  def handle_event("add", %{ "type" => type}, socket) do

    attrs = %{
      objectives: %{ "attached" => []},
      children: [],
      content: %{ "model" => []},
      title: if type == "Scored" do "New Assessment" else "New Page" end,
      graded: type == "Scored",
      max_attempts: if type == "Scored" do 5 else 0 end,
      recommended_attempts: if type == "Scored" do 5 else 0 end,
      scoring_strategy_id: ScoringStrategy.get_id_by_type("best"),
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page")
    }

    socket = case ContainerEditor.add_new(attrs, socket.assigns.author, socket.assigns.project) do

      {:ok, _} -> socket

      {:error, %Ecto.Changeset{} = _changeset} ->
        socket
        |> put_flash(:error, "Could not create page")
    end

    {:noreply, socket}
  end

  # When an activity that we are monitoring changes, we need to see if the changes
  # attached or detached any objectives.
  defp handle_updated_activity(socket, revision) do

    # if the attached objectives in this activity haven't changed - we ignore this
    # update, this allows for total optimization of this view as we will not re-render
    # anything

    old_activity = Map.get(socket.assigns.activity_map, revision.resource_id)

    get_objectves = fn %{objectives: objectives} -> (Enum.map(objectives, fn {_, ids} -> ids end) |> List.flatten() |> MapSet.new()) end

    old_objectives = get_objectves.(old_activity)
    updated_objectives = get_objectves.(revision)

    if MapSet.equal?(old_objectives, updated_objectives) do

      socket
    else

      activity_map = Map.put(socket.assigns.activity_map, revision.resource_id, revision)

      partial_activity_map = Map.put(%{}, revision.resource_id, revision)
      objective_map = Map.merge(socket.assigns.objective_map, build_objective_map(socket.assigns.project.slug, partial_activity_map))

      assign(socket, activity_map: activity_map, objective_map: objective_map)
    end

  end

  # We need to monitor for changes in the title of an objective
  defp handle_updated_objective(socket, revision) do
    objective_map = Map.put(socket.assigns.objective_map, revision.resource_id, revision)
    assign(socket, objective_map: objective_map)
  end

  defp has_renderable_change?(page1, page2) do

    page1.title != page2.title
    or page1.graded != page2.graded
    or page1.max_attempts != page2.max_attempts
    or page1.scoring_strategy_id != page2.scoring_strategy_id

  end

  defp handle_page(socket, revision) do

    id = revision.resource_id

    old_page = Enum.find(socket.assigns.pages, fn p -> p.resource_id == revision.resource_id end)

    has_changed? = has_renderable_change?(old_page, revision)

    # check to see if the activities in that page have changed since our last view of it
    current_activities = get_activities_from_page(Map.get(revision.content, "model")) |> MapSet.new
    old_page = Enum.find(socket.assigns.pages, fn p -> p.resource_id == revision.resource_id end)
    previous_activities = get_activities_from_page(Map.get(old_page.content, "model")) |> MapSet.new

    deleted_activities = MapSet.difference(previous_activities, current_activities) |> MapSet.to_list()
    added_activities = MapSet.difference(current_activities, previous_activities) |> MapSet.to_list()

    # We only track this update if it affects our rendering.  So we check to see if the
    # title or settings has changed of if the activities in this page haven't been added/removed
    if has_changed? or length(deleted_activities) > 0 or length(added_activities) > 0 do

      # we splice that page into its location
      pages = case Enum.find_index(socket.assigns.pages, fn p -> p.resource_id == id end) do
        nil -> socket.assigns.pages
        index -> List.replace_at(socket.assigns.pages, index, revision)
      end

      # update our selection to reflect the latest model
      selected = case socket.assigns.selected do
        nil -> nil
        s -> Enum.find(pages, fn r -> r.resource_id == s.resource_id end)
      end

      # update the relevant maps that allow us to show roll ups
      page_activity_map = Map.put(socket.assigns.page_activity_map, revision.resource_id, MapSet.to_list(current_activities))

      activity_map = Enum.reduce(deleted_activities, socket.assigns.activity_map, fn id, m -> Map.delete(m, id) end)

      {activity_map, objective_map} = case added_activities do

        [] -> {activity_map, socket.assigns.objective_map}

        activities ->

          resolved_activities = AuthoringResolver.from_resource_id(socket.assigns.project.slug, added_activities)

          partial_activity_map = resolved_activities
          |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.resource_id, a) end)

          activity_map = Map.merge(activity_map, partial_activity_map)

          objective_map = Map.merge(socket.assigns.objective_map, build_objective_map(socket.assigns.project.slug, partial_activity_map))

          {activity_map, objective_map}
      end

      assign(socket, selected: selected, pages: pages, page_activity_map: page_activity_map, activity_map: activity_map, objective_map: objective_map)

    else
      socket
    end
  end

  defp handle_container(socket, revision) do
    id = revision.resource_id

    # in the case of a change to the container, we simplify by just pulling a new view of
    # the container and its contents. This handles addition, removal, reordering from the
    # local user as well as a collaborator
    pages = ContainerEditor.list_all_pages(socket.assigns.project)
    page_activity_map = build_activity_to_page_map(pages)
    activity_map = build_activity_map(socket.assigns.project.slug, page_activity_map)
    objective_map = build_objective_map(socket.assigns.project.slug, activity_map)

    selected = case socket.assigns.selected do
      nil -> nil
      s -> Enum.find(pages, fn r -> r.resource_id == s.resource_id end)
    end

    assign(socket, selected: selected, root_resource: revision, pages: pages, page_activity_map: page_activity_map, activity_map: activity_map, objective_map: objective_map)

  end

  defp handle_page_or_container(socket, revision) do

    id = revision.resource_id

    # now determine if the change was to the container or to one of the pages itself
    if (socket.assigns.root_resource.resource_id == id) do
      handle_container(socket, revision)
    else
      handle_page(socket, revision)
    end

  end

  # Here we are listening for subscription notifications for edits made
  # to the container or to its child pages, contained activities and attached objectives
  def handle_info({:updated, revision, _}, socket) do

    socket = case Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
      "activity" -> handle_updated_activity(socket, revision)
      "objective" -> handle_updated_objective(socket, revision)
      _ -> handle_page_or_container(socket, revision)
    end

    # redo all subscriptions
    unsubscribe(socket.assigns.subscriptions, socket.assigns.project.slug)
    subscriptions = subscribe(socket.assigns.root_resource, socket.assigns.pages, socket.assigns.activity_map, socket.assigns.objective_map, socket.assigns.project.slug)

    {:noreply, assign(socket, subscriptions: subscriptions)}
  end

  # listens for creation of new objectives
  def handle_info({:new_resource, revision, _}, socket) do

    # include it in our objective map
    objective_map = Map.merge(socket.assigns.objective_map, Map.put(%{}, revision.resource_id, revision))

    # now listen to it for future edits
    PubSub.subscribe(Oli.PubSub, "resource:" <> Integer.to_string(revision.resource_id) <> ":project:" <> socket.assigns.project.slug)
    subscriptions = [revision.resource_id | socket.assigns.subscriptions]

    {:noreply, assign(socket, objective_map: objective_map, subscriptions: subscriptions)}
  end

end
