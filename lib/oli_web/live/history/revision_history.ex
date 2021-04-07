defmodule OliWeb.RevisionHistory do
  use Phoenix.LiveView

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources
  alias Oli.Publishing
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author
  alias OliWeb.RevisionHistory.Details
  alias OliWeb.RevisionHistory.Graph
  alias OliWeb.RevisionHistory.Table
  alias OliWeb.Common.Modal
  alias OliWeb.RevisionHistory.Pagination
  alias Oli.Authoring.Broadcaster
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Broadcaster.Subscriber
  alias OliWeb.Common.Breadcrumb

  @page_size 15

  def mount(%{ "slug" => slug, "project_id" => project_slug}, _, socket) do

    [{resource_id}] = Repo.all(from rev in Revision,
      distinct: rev.resource_id,
      where: rev.slug == ^slug,
      select: {rev.resource_id})

    project = Course.get_project_by_slug(project_slug)

    Subscriber.subscribe_to_new_revisions(resource_id)
    Subscriber.subscribe_to_new_publications(project_slug)

    revisions = fetch_all_revisions(resource_id)
    root = Enum.filter(revisions, fn r -> is_nil(r.previous_revision_id) end) |> hd
    tree = Oli.Versioning.RevisionTree.Tree.build(revisions, resource_id)

    mappings = Publishing.get_all_mappings_for_resource(resource_id, project_slug)
    mappings_by_revision = Enum.reduce(mappings, %{}, fn mapping, m -> Map.put(m, mapping.revision_id, mapping) end)

    selected = fetch_selected(hd(revisions).id)

    {:ok, assign(socket,
      breadcrumbs: [Breadcrumb.new(%{full_title: "Revision History"})],
      view: "table",
      tree: tree,
      root: root,
      resource_id: resource_id,
      mappings: mappings_by_revision,
      publication: determine_most_recent_published(mappings),
      revisions: revisions,
      selected: selected,
      project: project,
      page_offset: 0,
      initial_size: length(revisions))
    }
  end

  defp fetch_all_revisions(resource_id) do
    Repo.all(from rev in Revision,
      join: a in Author, on: a.id == rev.author_id,
      where: rev.resource_id == ^resource_id,
      order_by: [desc: rev.inserted_at],
      preload: [:author],
      select: map(rev, [:id, :previous_revision_id, :inserted_at, :updated_at, :author_id, :slug, :author_id, author: [:email]]))
  end

  defp fetch_selected(revision_id) do
    Repo.get!(Revision, revision_id)
  end

  # Sorts newest to oldest
  defp date_sort(d1, d2) do
    case NaiveDateTime.compare(d1, d2) do
      :lt -> false
      _ -> true
    end
  end

  defp determine_most_recent_published(mappings) do

    all = Enum.reduce(mappings, MapSet.new(), fn mapping, m -> MapSet.put(m, mapping.publication) end)
    |> MapSet.to_list()
    |> Enum.sort(fn m1, m2 -> date_sort(m1.inserted_at, m2.inserted_at) end)

    case length(all) do
      1 -> nil
      _ -> Enum.at(all, 1)
    end

  end

  def render(assigns) do

    size = @page_size

    ~L"""
    <h2>Revision History<h2>
    <h4>Resource ID: <%= @resource_id %></h4>

    <div class="row" style="margin-bottom: 30px;">
      <div class="col-sm-12">
        <div class="card">
          <div class="card-header">
            Revisions

            <div class="btn-group btn-group-toggle" data-toggle="buttons"  style="float: right;">
              <label phx-click="table" class="btn btn-sm btn-secondary <%= if @view == "table" do "active" else "" end %>">
                <input type="radio" name="options" id="option1"
                  <%= if @view == "table" do "checked" else "" end %>
                > <span><i class="fas fa-table"></i></span>
              </label>
              <label phx-click="graph" class="btn btn-sm btn-secondary <%= if @view == "graph" do "active" else "" end %>">
                <input type="radio" name="options" id="option2"
                  <%= if @view == "graph" do "checked" else "" end %>
                > <span><i class="fas fa-project-diagram"></i></span>
              </label>
            </div>

            </span>
          </div>
          <div class="card-body">
            <%= if @view == "graph" do %>
              <%= live_component @socket, Graph, tree: @tree, root: @root, selected: @selected, project: @project, initial_size: @initial_size %>
            <% else %>
              <%= live_component @socket, Pagination, revisions: @revisions, page_offset: @page_offset, page_size: size %>
              <%= live_component @socket, Table, tree: @tree, publication: @publication, mappings: @mappings, revisions: @revisions, selected: @selected, page_offset: @page_offset, page_size: size %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    <div class="row">
      <div class="col-sm-12">
        <div class="card">
          <div class="card-header">
            Selected Revision Details
            <div style="float: right;">
              <button type="button" class="btn btn-outline-danger btn-sm" data-toggle="modal" data-target="#restoreModal">
                Restore
              </button>
            </div>
          </div>
          <div class="card-body">
            <%= live_component @socket, Details, revision: @selected %>
          </div>
        </div>
      </div>
    </div>

    <%= live_component @socket, Modal, title: "Restore this Revision", modal_id: "restoreModal", ok_action: "restore", ok_label: "Proceed", ok_style: "btn-danger" do %>
      <p class="mb-4">Are you sure you want to restore this revision?</p>

      <p>This will end any active editing session for other users and will create a
         new revision to restore the title, content and objectives and other settings
         of this selected revision.</p>
    <% end %>
    """
  end

  # creates a new revision by restoring the state of the selected revision
  def handle_event("restore", _, socket) do

    project_slug = socket.assigns.project.slug
    resource_id = socket.assigns.resource_id

    # First clear any lock that might be present on this resource.  Clearing the lock
    # is necessary to prevent an active editing session from stomping on what is about
    # to be restored
    publication = AuthoringResolver.publication(project_slug)
    Publishing.get_published_resource!(publication.id, resource_id)
    |> Publishing.update_published_resource(%{ lock_updated_at: nil, locked_by_id: nil })

    # Now create and track the new revision, based on the current head for this project but
    # restoring the content, title and objectives and other settigns from the selected revision
    %Revision{content: content,
      title: title,
      objectives: objectives,
      scoring_strategy_id: scoring_strategy_id,
      graded: graded,
      max_attempts: max_attempts,
      author_id: author_id} = socket.assigns.selected

    {:ok, revision} = AuthoringResolver.from_resource_id(project_slug, resource_id)
    |> Resources.create_revision_from_previous(
      %{author_id: author_id, content: content, title: title, objectives: objectives,
        scoring_strategy_id: scoring_strategy_id, graded: graded, max_attempts: max_attempts })

    Oli.Publishing.ChangeTracker.track_revision(project_slug, revision)

    Broadcaster.broadcast_revision(revision, project_slug)

    {:noreply, socket}
  end

  def handle_event("select", %{ "rev" => str}, socket) do

    id = String.to_integer(str)
    selected = fetch_selected(id)
    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("table", _, socket) do
    {:noreply, assign(socket, :view, "table")}
  end

  def handle_event("graph", _, socket) do
    {:noreply, assign(socket, view: "graph")}
  end

  def handle_event("page", %{ "ordinal" => ordinal}, socket) do
    page_offset = (String.to_integer(ordinal) - 1) * @page_size
    {:noreply, assign(socket, :page_offset, page_offset)}
  end

  def handle_info({:updated, revision, _}, socket) do

    id = revision.id

    revision = Oli.Resources.get_revision!(id) |>  Repo.preload(:author)

    revisions = case socket.assigns.revisions do
      [] -> [revision]
      [%{id: ^id} | rest] -> [revision] ++ rest
      list -> [revision] ++ list
    end

    selected = if revision.id == socket.assigns.selected.id do
      revision
    else
      socket.assigns.selected
    end

    tree = case Map.get(socket.assigns.tree, revision.id) do
      nil -> Oli.Versioning.RevisionTree.Tree.build(revisions, socket.assigns.resource_id)
      node -> Map.put(socket.assigns.tree, revision.id, %{node | revision: revision})
    end

    {:noreply, assign(socket, selected: selected, revisions: revisions, tree: tree)}
  end

  def handle_info({:new_publication, _, _}, socket) do

    mappings = Publishing.get_all_mappings_for_resource(socket.assigns.resource_id, socket.assigns.project.slug)
    mappings_by_revision = Enum.reduce(mappings, %{}, fn mapping, m -> Map.put(m, mapping.revision_id, mapping) end)

    {:noreply, assign(socket, mappings: mappings_by_revision, publication: determine_most_recent_published(mappings))}
  end


end
