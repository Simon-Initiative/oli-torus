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
    subscriptions = subscribe(root_resource, pages, project.slug)

    {:ok, assign(socket,
      conn: socket,
      pages: pages,
      title: "Curriculum",
      changeset: Resources.change_revision(%Revision{}),
      root_resource: root_resource,
      project: project,
      subscriptions: subscriptions,
      author: author,
      selected: nil)
    }
  end

  def render(assigns) do

    ~L"""
    <div style="margin: 20px;">

      <div class="container">
        <div class="row">
          <div class="col-12">
            <small class="text-muted">
              Create and configure the curriculum items for your course.
            </small>
          </div>
        </div>
        <div class="row" phx-window-keydown="keydown">
          <div class="col-12 col-md-8">

            <div class="curriculum-entries">
              <%= for {page, index} <- Enum.with_index(@pages) do %>
                <%= live_component @socket, DropTarget, index: index %>
                <%= live_component @socket, Entry, selected: page == @selected, page: page, index: index, project: @project %>
              <% end %>
              <%= live_component @socket, DropTarget, index: length(@pages) %>
            </div>

            <div class="mt-5">
              Add new:
              <button phx-click="add" phx-value-type="Unscored" class="btn btn-sm btn-secondary-outline ml-2" type="button">
                Practice Page
              </button>
              <button phx-click="add" phx-value-type="Scored" class="btn btn-sm btn-secondary-outline ml-2" type="button">
                Graded Assessment
              </button>
            </div>

          </div>

          <div class="col-12 col-md-4">
            <%= if @selected != nil do %>
            <%= live_component @socket, Settings, page: @selected, changeset: @changeset %>
            <% end %>
          </div>
        </div>

      </div>

    </div>
    """
  end

  # spin up subscriptions for the container and for all of its pages
  defp subscribe(root_resource, pages, project_slug) do

    ids = [root_resource.resource_id] ++ Enum.map(pages, fn p -> p.resource_id end)
    Enum.each(ids, fn id -> PubSub.subscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, project_slug) do
    Enum.each(ids, fn id -> PubSub.unsubscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)
  end

  defp move_selection(pages, index, direction) do
    Enum.at(pages, index + direction)
  end

  # handle change of selection
  def handle_event("select", %{ "slug" => slug}, socket) do
    selected = Enum.find(socket.assigns.pages, fn r -> r.slug == slug end)
    {:noreply, assign(socket, :selected, selected)}
  end

  # process form submission to save page settings
  def handle_event("save", params, socket) do

    socket = case ContainerEditor.edit_page(socket.assigns.project, socket.assigns.selected.slug, params) do
      {:ok, _} -> socket
      {:error, _} -> socket
      |> put_flash(:error, "Could not edit page")
    end

    {:noreply, socket}
  end

  # allow key up and down to change the selected item
  def handle_event("keydown", %{"key" => key}, socket) do

    index = Enum.find_index(socket.assigns.pages, fn p -> p == socket.assigns.selected end)
    last_index = length(socket.assigns.pages) - 1
    pages = socket.assigns.pages

    case {index, key} do
      {nil, _} -> {:noreply, socket}
      {^last_index, "ArrowDown"} -> {:noreply, socket}
      {0, "ArrowUp"} -> {:noreply, socket}
      {index, "ArrowUp"} -> {:noreply, assign(socket, :selected, move_selection(pages, index, -1))}
      {index, "ArrowDown"} -> {:noreply, assign(socket, :selected, move_selection(pages, index, 1))}
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

  # Here are listening for subscription notifications for edits made
  # to the container or to its child pages
  def handle_info({:updated, revision, _}, socket) do

    id = revision.resource_id

    # now determine if the change was to the container or to one of the pages itself
    {pages, root_resource} = if (socket.assigns.root_resource.resource_id == id) do

      # in the case of a change to the container, we simplify by just pulling a new view of
      # the container and its contents. This handles addition, removal, reordering from the
      # local user as well as a collaborator
      pages = ContainerEditor.list_all_pages(socket.assigns.project)
      {pages, revision}
    else

      # on just a page change, we splice that page into its location
      pages = case Enum.find_index(socket.assigns.pages, fn p -> p.resource_id == id end) do
        nil -> socket.assigns.pages
        index -> List.replace_at(socket.assigns.pages, index, revision)
      end
      {pages, socket.assigns.root_resource}
    end

    # update our selection to reflect the latest model
    selected = case socket.assigns.selected do
      nil -> nil
      s -> Enum.find(pages, fn r -> r.resource_id == s.resource_id end)
    end

    # redo all subscriptions
    unsubscribe(socket.assigns.subscriptions, socket.assigns.project.slug)
    subscriptions = subscribe(root_resource, pages, socket.assigns.project.slug)

    {:noreply, assign(socket, selected: selected, pages: pages, root_resource: root_resource, subscriptions: subscriptions)}
  end


end
