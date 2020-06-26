defmodule OliWeb.RevisionHistory do
  use Phoenix.LiveView

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources
  alias Oli.Publishing
  alias Phoenix.PubSub

  alias OliWeb.RevisionHistory.Details
  alias OliWeb.RevisionHistory.Graph
  alias OliWeb.RevisionHistory.Table
  alias OliWeb.Common.Modal
  alias OliWeb.RevisionHistory.Pagination
  alias Oli.Authoring.Broadcaster
  alias Oli.Publishing.AuthoringResolver

  @page_size 15

  def mount(%{ "slug" => slug, "project_id" => project_slug}, _, socket) do

    [{resource_id}] = Repo.all(from rev in Revision,
      distinct: rev.resource_id,
      where: rev.slug == ^slug,
      select: {rev.resource_id})

    PubSub.subscribe Oli.PubSub, "resource:" <> Integer.to_string(resource_id)

    revisions = Repo.all(from rev in Revision,
      where: rev.resource_id == ^resource_id,
      order_by: [desc: rev.inserted_at],
      select: rev)

    selected = hd(revisions)

    {:ok, assign(socket,
      title: "Revision History",
      view: "table",
      resource_id: resource_id,
      revisions: revisions,
      selected: selected,
      project_slug: project_slug,
      page_offset: 0,
      initial_size: length(revisions))
    }
  end

  def render(assigns) do

    reversed = Enum.reverse(assigns.revisions)
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
              <%= live_component @socket, Graph, revisions: reversed, selected: @selected, initial_size: @initial_size %>
            <% else %>
              <%= live_component @socket, Pagination, revisions: @revisions, page_offset: @page_offset, page_size: size %>
              <%= live_component @socket, Table, revisions: @revisions, selected: @selected, page_offset: @page_offset, page_size: size %>
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

    project_slug = socket.assigns.project_slug
    resource_id = socket.assigns.resource_id

    # First clear any lock that might be present on this resource.  Clearing the lock
    # is necessary to prevent an active editing session from stomping on what is about
    # to be restored
    publication = AuthoringResolver.publication(project_slug)
    Publishing.get_resource_mapping!(publication.id, resource_id)
    |> Publishing.update_resource_mapping(%{ lock_updated_at: nil, locked_by_id: nil })

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
    selected = Enum.find(socket.assigns.revisions, fn r -> r.id == id end)
    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("table", _, socket) do
    {:noreply, assign(socket, :view, "table")}
  end

  def handle_event("graph", _, socket) do
    {:noreply, assign(socket, :view, "graph")}
  end

  def handle_event("page", %{ "ordinal" => ordinal}, socket) do
    page_offset = (String.to_integer(ordinal) - 1) * @page_size
    {:noreply, assign(socket, :page_offset, page_offset)}
  end

  def handle_info({:updated, revision, _}, socket) do

    id = revision.id

    revisions = case socket.assigns.revisions do
      [] -> [revision]
      [%{id: ^id} | rest] -> [revision] ++ rest
      list -> [revision] ++ list
    end

    selected = Enum.find(revisions, fn r -> r.id == socket.assigns.selected.id end)

    {:noreply, assign(socket, selected: selected, revisions: revisions)}
  end


end
