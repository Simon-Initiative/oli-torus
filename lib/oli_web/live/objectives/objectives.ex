defmodule OliWeb.Objectives.Objectives do

  @moduledoc """
  LiveView implementation of an objective editor.
  """

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Authoring.Editing.ObjectiveEditor
  alias OliWeb.Objectives.ObjectiveEntry
  alias OliWeb.Objectives.ObjectiveRender
  alias Oli.Publishing.ObjectiveMappingTransfer
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author

  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Repo
  alias Phoenix.PubSub

  def mount(params, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(Map.get(params, "project_id"))

    objective_mappings = ObjectiveEditor.fetch_objective_mappings(project)

    subscriptions = subscribe(objective_mappings, project.slug)

    objectives_tree = to_objective_tree(objective_mappings)

    {:ok, assign(socket,
      objective_mappings: objective_mappings,
      objectives_tree: objectives_tree,
      title: "Objectives",
      changeset: Resources.change_revision(%Revision{}),
      project: project,
      subscriptions: subscriptions,
      author: author,
      selected: nil,
      edit: :none)
    }
  end

  def render(assigns) do

    ~L"""
    <div style="margin: 20px;">
      <div class="container">
      <div class="mb-2 row">
        <h2>Course Objectives</h2>
        <p class="text-secondary">
         Learning objectives help you to organize course content and determine appropriate assessments and instructional strategies.
         Visit the <a href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html" target="_blank">CMU Eberly Center guide on learning objectives</a> to learn more about the importance of attaching learning objectives to pages and activities.
        </p>
        <p class="text-secondary">At the end of the course my students should be able to...</p>
      </div>
        <div class="mb-2 row">
          <%= live_component @socket, ObjectiveRender, changeset: @changeset, project: @project, form_id: "create-objective",
            place_holder: "New Learning Objective", title_value: "", slug_value: "", parent_slug_value: "",
            edit: @edit, method: "new", mode: :new_objective, phx_disable_with: "Adding Objective...", button_text: "Create" %>
        </div>
        <%= if Enum.count(@objective_mappings) == 0 do %>
        <div class="row">
          <div class="my-5 text-center">
            No objectives
          </div>
        </div>
        <% else %>
        <div class="row">
          <div class="border border-light list-group list-group-flush w-100">
              <%= for {objective_tree, index} <- Enum.with_index(@objectives_tree) do %>
                <%= live_component @socket, ObjectiveEntry, changeset: @changeset, objective_mapping: objective_tree.mapping,
                    children: objective_tree.children, depth: 1, index: index, project: @project, selected: @selected, edit: @edit %>
              <% end %>
          </div>
      <div class="modal fade" id="exampleModalCenter" tabindex="-1" role="dialog" aria-labelledby="exampleModalCenterTitle" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLongTitle">Delete Objective</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            <p>Are you sure you want to delete this objective?</p>
            <p>This is an operation that cannot be undone.</p>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-danger" data-dismiss="modal" phx-click="delete">Delete</button>
          </div>
        </div>
      </div>
    </div>
        </div>
        <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp to_objective_tree(objective_mappings) do
    if Enum.empty?(objective_mappings) do
       []
    else
      # Extract all children references from objectives
      children_list = objective_mappings
                      |> Enum.map(fn mapping -> mapping.revision.children end)
                      |> Enum.reduce(fn(children, acc) -> children ++ acc end)

      # Build flat ObjectiveMappingTransfer map for all objectives
      mapping_obs = objective_mappings |>  Enum.reduce(%{}, fn(mapping, acc) ->
        Map.merge(acc, %{mapping.resource.id => %ObjectiveMappingTransfer{mapping: mapping, children: []}})
      end)

      # Build nested tree structure
      root_parents = Enum.reduce(objective_mappings, [], fn(m, acc) ->
        a = Map.get(mapping_obs, m.resource.id)
        a = %{a | children: m.revision.children |> Enum.reduce(a.children,fn(c, mc) ->
          val = Map.get(mapping_obs, c)
          if is_nil(val) do
            mc
          else
            [val] ++ mc
          end
        end)}
        if !Enum.member?(children_list, m.resource.id) do
          acc ++ [a]
        else
          acc
        end
      end)

      Enum.sort_by(root_parents, &(&1.mapping.revision.title))
    end
  end

  # spin up subscriptions for the container and for all of its objectives
  defp subscribe(objective_mappings, project_slug) do
    ids = Enum.map(objective_mappings, fn p -> p.resource.id end)
    Enum.each(ids, fn id -> PubSub.subscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)

    PubSub.subscribe(Oli.PubSub, "resource_type:" <> Integer.to_string(ResourceType.get_id_by_type("objective")) <> ":project:" <> project_slug)

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, project_slug) do
    Enum.each(ids, fn id -> PubSub.unsubscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)
    PubSub.unsubscribe(Oli.PubSub, "resource_type:" <> Integer.to_string(ResourceType.get_id_by_type("objective")) <> ":project:" <> project_slug)
  end

  def handle_event("keydown", %{"slug" => slug, "key" => key}, socket) do
    case key do
      "Enter" -> handle_event("select", %{"slug" => slug}, socket)
      _ -> {:noreply, socket}
    end
  end

  # handle change of selection
  def handle_event("select", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, :selected, slug)}
  end

  # handle change of edit
  def handle_event("modify", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, :edit, slug)}
  end

  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, :edit, :none)}
  end

  # process form submission to save page settings
  def handle_event("edit", %{"revision" => objective_params}, socket) do
    with_atom_keys = Map.keys(objective_params)
                     |> Enum.reduce(%{}, fn k, m -> Map.put(m, String.to_atom(k), Map.get(objective_params, k)) end)
    socket = case ObjectiveEditor.edit(Map.get(with_atom_keys,:slug), with_atom_keys, socket.assigns.author, socket.assigns.project) do
      {:ok, _} -> socket
      {:error, _} -> socket
      |> put_flash(:error, "Could not edit objective")
    end

    {:noreply, socket}
  end

  # handle processing deletion of item
  def handle_event("delete", _, socket) do
    socket = case ObjectiveEditor.edit(socket.assigns.selected, %{ deleted: true }, socket.assigns.author, socket.assigns.project) do
      {:ok, _} -> socket
      {:error, _} -> socket
      |> put_flash(:error, "Could not remove objective")
    end

    {:noreply, socket}
  end

  # handle clicking of the add objective
  def handle_event("new", %{"revision" => objective_params}, socket) do
    with_atom_keys = Map.keys(objective_params)
                     |> Enum.reduce(%{}, fn k, m -> Map.put(m, String.to_atom(k), Map.get(objective_params, k)) end)

    container_slug = Map.get(objective_params, "parent_slug")

    socket = case ObjectiveEditor.add_new(with_atom_keys, socket.assigns.author, socket.assigns.project, container_slug) do
      {:ok, _} -> socket
      {:error, %Ecto.Changeset{} = _changeset} ->
        socket
        |> put_flash(:error, "Could not create objective")
    end

    {:noreply, socket}
  end

  # Here are listening for subscription notifications for newly created resources
  def handle_info({:added, revision, _}, socket) do
    process_info({:added, revision}, socket)
  end

  # Listener for edits to existing resources
  def handle_info({:updated, revision, _}, socket) do
    process_info({:updated, revision}, socket)
  end

  defp process_info({any, revision}, socket) do
    id = revision.resource_id

    # For a completely new resource, we simply pull a new view of the objective mappings
    objective_mappings = if any == :added do
      ObjectiveEditor.fetch_objective_mappings(socket.assigns.project)

    else
      # on just an objective change, update the revision in place
      case Enum.find_index(socket.assigns.objective_mappings, fn p -> p.resource.id == id end) do
        nil -> socket.assigns.objective_mappings
        index -> case revision.deleted do
          false ->
            mapping = %{Enum.at(socket.assigns.objective_mappings, index) | revision: revision}
            List.replace_at(socket.assigns.objective_mappings, index, mapping)
          true ->
            List.delete_at(socket.assigns.objective_mappings, index)
        end
      end
    end

    # redo all subscriptions
    unsubscribe(socket.assigns.subscriptions, socket.assigns.project.slug)
    subscriptions = subscribe(objective_mappings, socket.assigns.project.slug)

    objectives_tree = to_objective_tree(objective_mappings)

    {:noreply, assign(socket, objective_mappings: objective_mappings, objectives_tree: objectives_tree,
      subscriptions: subscriptions)}
  end
end
