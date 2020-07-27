defmodule OliWeb.Objectives.Objectives do

  @moduledoc """
  LiveView implementation of an objective editor.
  """

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Authoring.Editing.ObjectiveEditor
  alias OliWeb.Objectives.ObjectiveEntry
  alias OliWeb.Objectives.CreateNew
  alias OliWeb.Objectives.Attachments
  alias OliWeb.Objectives.Actions
  alias OliWeb.Common.ManualModal
  alias Oli.Publishing.ObjectiveMappingTransfer
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author

  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Repo
  alias Phoenix.PubSub

  @default_attachment_summary %{attachments: {[], []}, locked_by: %{}, parent_pages: %{}}

  def mount(params, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(Map.get(params, "project_id"))

    objective_mappings = ObjectiveEditor.fetch_objective_mappings(project)

    subscriptions = subscribe(objective_mappings, project.slug)

    objectives_tree = to_objective_tree(objective_mappings)

    selected = case length(objectives_tree) do
      0 -> nil
      _ -> hd(objectives_tree).mapping.revision.slug
    end

    {:ok, assign(socket,
      active: :objectives,
      objective_mappings: objective_mappings,
      objectives_tree: objectives_tree,
      title: "Objectives",
      changeset: Resources.change_revision(%Revision{}),
      project: project,
      subscriptions: subscriptions,
      attachment_summary: @default_attachment_summary,
      modal_shown: false,
      author: author,
      force_render: 0,
      is_root_selected?: false,
      can_delete?: false,
      selected: selected,
      edit: :none)
    }
  end

  def render(assigns) do
    ~L"""
    <div class="objectives container objectives-authoring">
      <div class="mb-2 row">
        <div class="col-12">
          <p class="text-secondary">
            Learning objectives help you to organize course content and determine appropriate assessments and instructional strategies.
          </p>
          <p class="text-secondary">
            Visit the <a href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html" target="_blank">CMU Eberly Center guide on learning objectives</a> to learn more about the importance of attaching learning objectives to pages and activities.
          </p>
        </div>
      </div>

      <%= live_component @socket, CreateNew, changeset: @changeset, project: @project %>

      <div class="mt-5 row">
        <div class="col-12">
          <div class="d-flex justify-content-between">
            <h2>Existing Objectives</h2>
            <%= live_component @socket, Actions, selected: @selected, is_root?: @is_root_selected?, can_delete?: @can_delete? %>
          </div>
        </div>
      </div>

      <%= if Enum.count(@objective_mappings) == 0 do %>
        <div class="mt-1 row">
          <div class="col-12">
            <p>This project has no objectives</p>
          </div>
        </div>
      <% else %>

        <%= for {objective_tree, index} <- Enum.with_index(@objectives_tree) do %>
          <%= live_component @socket, ObjectiveEntry, changeset: @changeset, objective_mapping: objective_tree.mapping,
            children: objective_tree.children, depth: 1, index: index, project: @project, selected: @selected, edit: @edit %>
        <% end %>

      <% end %>

    </div>

    <%= if @modal_shown do %>
      <%= live_component @socket, ManualModal, title: "Delete Objective", modal_id: "deleteModal", ok_action: "delete", ok_label: "Delete", ok_style: "btn-danger" do %>
        <%= live_component @socket, Attachments, attachment_summary: @attachment_summary, project: @project %>
      <% end %>
    <% end %>

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
      Enum.reduce(objective_mappings, [], fn(m, acc) ->
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
      |> Enum.sort(fn e1, e2 -> e1.mapping.resource.inserted_at <= e2.mapping.resource.inserted_at end)

    end
  end

  # spin up subscriptions for the container and for all of its objectives
  defp subscribe(objective_mappings, project_slug) do
    ids = Enum.map(objective_mappings, fn p -> p.resource.id end)
    Enum.each(ids, fn id -> PubSub.subscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)

    PubSub.subscribe(Oli.PubSub, "new_resource:resource_type:" <> Integer.to_string(ResourceType.get_id_by_type("objective")) <> ":project:" <> project_slug)

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, project_slug) do
    Enum.each(ids, fn id -> PubSub.unsubscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)
    PubSub.unsubscribe(Oli.PubSub, "new_resource:resource_type:" <> Integer.to_string(ResourceType.get_id_by_type("objective")) <> ":project:" <> project_slug)
  end

  def handle_event("keydown", %{"slug" => slug, "key" => key}, socket) do
    case key do
      "Enter" -> handle_event("select", %{"slug" => slug}, socket)
      _ -> {:noreply, socket}
    end
  end

  # handle change of selection
  def handle_event("select", %{"slug" => slug}, socket) do

    {is_root_selected?, can_delete?} = case Enum.find(socket.assigns.objectives_tree, fn %{mapping: mapping} -> mapping.revision.slug == slug end) do
      nil -> {false, true}
      %{mapping: mapping} -> {true, length(mapping.revision.children) == 0}
    end

    {:noreply, assign(socket, selected: slug, can_delete?: can_delete?, is_root_selected?: is_root_selected?, attachment_summary: @default_attachment_summary)}
  end

  # handle change of edit
  def handle_event("modify", %{"slug" => slug}, socket) do

    {:noreply, assign(socket, :edit, slug)}
  end

  def handle_event("add_sub", %{"slug" => slug}, socket) do

    # even though we disable the "add sub objective" button when a non-root is selected,
    # LV seems to still send the add_sub message on click.  So we catch that case here
    # and ignore it
    case socket.assigns.is_root_selected? do
      true -> {:noreply, assign(socket, :edit, slug)}
      false -> {:noreply, socket}
    end

  end


  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, :edit, :none)}
  end

  # process form submission to save page settings
  def handle_event("edit", %{"revision" => objective_params}, socket) do
    with_atom_keys = Map.keys(objective_params)
                     |> Enum.reduce(%{}, fn k, m -> Map.put(m, String.to_existing_atom(k), Map.get(objective_params, k)) end)
    socket = case ObjectiveEditor.edit(Map.get(with_atom_keys,:slug), with_atom_keys, socket.assigns.author, socket.assigns.project) do
      {:ok, _} -> socket
      {:error, _} -> socket
      |> put_flash(:error, "Could not edit objective")
    end

    {:noreply, assign(socket, :edit, :none)}
  end

  def handle_event("prepare_delete", _, socket) do

    if socket.assigns.can_delete? do
      attachment_summary = ObjectiveEditor.preview_objective_detatchment(socket.assigns.selected, socket.assigns.project)
      {:noreply, assign(socket, modal_shown: true, attachment_summary: attachment_summary, force_render: socket.assigns.force_render + 1)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, assign(socket, modal_shown: false)}
  end

  # handle processing deletion of item
  def handle_event("delete", _, socket) do

    ObjectiveEditor.detach_objective(socket.assigns.selected, socket.assigns.project, socket.assigns.author)

    parent_objective = determine_parent_objective(socket, socket.assigns.selected)

    socket = case ObjectiveEditor.preview_objective_detatchment(socket.assigns.selected, socket.assigns.project) do
      %{attachments: {[], []}} -> case ObjectiveEditor.delete(socket.assigns.selected, socket.assigns.author, socket.assigns.project, parent_objective) do
        {:ok, _} -> socket
        {:error, _} -> socket
        |> put_flash(:error, "Could not remove objective")
      end
      _ -> socket
    end

    {:noreply, assign(socket, modal_shown: false)}
  end

  # handle clicking of the add objective
  def handle_event("new", %{"revision" => objective_params}, socket) do
    with_atom_keys = Map.keys(objective_params)
                     |> Enum.reduce(%{}, fn k, m -> Map.put(m, String.to_existing_atom(k), Map.get(objective_params, k)) end)

    container_slug = Map.get(objective_params, "parent_slug")

    socket = case ObjectiveEditor.add_new(with_atom_keys, socket.assigns.author, socket.assigns.project, container_slug) do
      {:ok, _} ->
        IO.inspect("Added new objective")
        assign(socket, :changeset, Resources.change_revision(%Revision{}))
      {:error, %Ecto.Changeset{} = _changeset} ->
        socket
        |> put_flash(:error, "Could not create objective")
    end

    {:noreply, IO.inspect(assign(socket, :edit, :none), label: "Socket")}
  end


  defp determine_parent_objective(socket, slug) do

    child = Enum.find(socket.assigns.objective_mappings, fn %{ revision: revision } -> revision.slug == slug end)

    case Enum.find(socket.assigns.objectives_tree, fn %{mapping: mapping} -> Enum.any?(mapping.revision.children, fn id -> id == child.revision.resource_id end) end) do
      nil -> nil
      o -> o.mapping.revision
    end

  end

  # Here are listening for subscription notifications for newly created resources
  def handle_info({:new_resource, revision, _}, socket) do
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
