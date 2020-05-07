defmodule OliWeb.Insights do
  use Phoenix.LiveView

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Phoenix.PubSub

  def mount(params, _, socket) do

    # [{resource_id}] = Repo.all(from rev in Revision,
    #   distinct: rev.resource_id,
    #   where: rev.slug == ^slug,
    #   select: {rev.resource_id})

    # PubSub.subscribe Oli.PubSub, "resource:" <> Integer.to_string(resource_id)

    # revisions = Repo.all(from rev in Revision,
    #   where: rev.resource_id == ^resource_id,
    #   order_by: [desc: rev.inserted_at],
    #   select: rev)

    # selected = hd(revisions)

    # {:ok, assign(socket,
    #   resource_id: resource_id,
    #   revisions: revisions,
    #   selected: selected,
    #   initial_size: length(revisions))
    # }
    {:ok, socket}
  end

  def render(assigns) do

    ~L"""
    Liveview component
    """
    # <%= live_component @socket, Graph, revisions: reversed, selected: @selected, initial_size: @initial_size %>
    # <%= live_component @socket, Details, revision: @selected %>
  end

  def handle_event("select", %{ "rev" => str}, socket) do
    {:noreply}
    # {:noreply, assign(socket, :selected, selected)}
  end

  def handle_info({:updated, revision}, socket) do
    {:noreply}
    # {:noreply, assign(socket, selected: selected, revisions: revisions)}
  end


end
