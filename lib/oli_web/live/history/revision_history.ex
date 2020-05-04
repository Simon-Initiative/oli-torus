defmodule OliWeb.RevisionHistory do
  use Phoenix.LiveView

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Phoenix.PubSub

  alias OliWeb.RevisionHistory.Details
  alias OliWeb.RevisionHistory.Graph
  alias OliWeb.RevisionHistory.Table

  def mount(%{ "slug" => slug}, _, socket) do

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
      resource_id: resource_id,
      revisions: revisions,
      selected: selected,
      initial_size: length(revisions))
    }
  end

  def render(assigns) do

    reversed = Enum.reverse(assigns.revisions)

    ~L"""
    <h2>Revision History<h2>
    <h4>Resource ID: <%= @resource_id %></h4>

    <div class="row" style="margin-bottom: 30px;">
      <div class="col-sm-12">
        <div class="card">
          <div class="card-header">
            Revision Graph
          </div>
          <div class="card-body">
            <%= live_component @socket, Graph, revisions: reversed, selected: @selected, initial_size: @initial_size %>
          </div>
        </div>
      </div>
    </div>
    <div class="row">
      <div class="col-sm-6">
        <div class="card">
          <div class="card-header">
            Tabular Display
          </div>
          <div class="card-body">
            <%= live_component @socket, Table, revisions: @revisions, selected: @selected %>
          </div>
        </div>
      </div>
      <div class="col-sm-6">
        <div class="card">
          <div class="card-header">
            Selected Revision Details
          </div>
          <div class="card-body">
            <%= live_component @socket, Details, revision: @selected %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("select", %{ "rev" => str}, socket) do

    id = String.to_integer(str)
    selected = Enum.find(socket.assigns.revisions, fn r -> r.id == id end)
    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_info({:updated, revision}, socket) do

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
