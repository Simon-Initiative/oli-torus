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

  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Accounts.Author
  alias Oli.Repo
  alias Phoenix.PubSub

  def mount(params, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(Map.get(params, "project_id"))

    objective_mappings = ObjectiveEditor.fetch_objective_mappings(project)

    root_resource = AuthoringResolver.root_resource(project.slug)

    subscriptions = subscribe(root_resource, objective_mappings, project.slug)

    objectives_tree = to_objective_tree(objective_mappings)

    {:ok, assign(socket,
      objective_mappings: objective_mappings,
      objectives_tree: objectives_tree,
      title: "Objectives",
      changeset: Resources.change_revision(%Revision{}),
      root_resource: root_resource,
      project: project,
      subscriptions: subscriptions,
      author: author,
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
                    children: objective_tree.children, depth: 1, index: index, project: @project, edit: @edit %>
              <% end %>
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
  defp subscribe(root_resource, objective_mappings, project_slug) do
    ids = [root_resource.resource_id] ++ Enum.map(objective_mappings, fn p -> p.resource.id end)
    Enum.each(ids, fn id -> PubSub.subscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)
    PubSub.subscribe(Oli.PubSub, "resource_type:" <> Integer.to_string(ResourceType.get_id_by_type("objective")) <> ":project:" <> project_slug)
    [Oli.Resources.ResourceType.get_id_by_type("objective")] ++ ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, project_slug) do
    Enum.each(ids, fn id -> PubSub.unsubscribe(Oli.PubSub, "resource:" <> Integer.to_string(id) <> ":project:" <> project_slug) end)
  end

  # handle change of edit
  def handle_event("modify", %{ "slug" => slug}, socket) do
    {:noreply, assign(socket, :edit, slug)}
  end

  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, :edit, :none)}
  end

  # process form submission to save page settings
  def handle_event("edit", %{ "revision" => objective_params}, socket) do
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
  def handle_event("delete", %{ "slug" => slug}, socket) do
    socket = case ObjectiveEditor.edit(slug, %{ deleted: true }, socket.assigns.author, socket.assigns.project) do
      {:ok, _} -> socket
      {:error, _} -> socket
      |> put_flash(:error, "Could not remove objective")
    end

    {:noreply, socket}
  end

  # handle clicking of the "Add Graded Assessment" or "Add Practice Page" buttons
  def handle_event("new", %{ "revision" => objective_params}, socket) do
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

  # Here are listening for subscription notifications for edits made
  # to the container or to its child pages
  def handle_info({:added, revision, project_slug}, socket) do
    if revision.resource_type_id == ResourceType.get_id_by_type("objective")
      && project_slug == socket.assigns.project.slug do
      process_info({:added, revision}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, revision, _}, socket) do
    process_info({:deleted, revision}, socket)
  end

  def handle_info({:updated, revision, _}, socket) do
    process_info({:updated, revision}, socket)
  end

  defp process_info({any, revision}, socket) do
    id = revision.resource_id

    # now determine if the change was to the container or to one of the objectives itself
    {objective_mappings, root_resource} = if (socket.assigns.root_resource.resource_id == id)
      || any == :added do
      # in the case of a change to the container, we simplify by just pulling a new view of
      # the container and its contents.
      objective_mappings = ObjectiveEditor.fetch_objective_mappings(socket.assigns.project)
      {objective_mappings, revision}
    else
      # on just an objective change, updated the revision in place
      objective_mappings = case Enum.find_index(socket.assigns.objective_mappings, fn p -> p.resource.id == id end) do
        nil -> socket.assigns.objective_mappings
        index -> cond  do
                   any == :updated ->
                     mapping = %{Enum.at(socket.assigns.objective_mappings, index) | revision: revision}
                     List.replace_at(socket.assigns.objective_mappings, index, mapping)
                   any == :deleted -> List.delete_at(socket.assigns.objective_mappings, index)
                   true -> socket.assigns.objective_mappings
                 end
      end
      {objective_mappings, socket.assigns.root_resource}
    end

    # redo all subscriptions
    unsubscribe(socket.assigns.subscriptions, socket.assigns.project.slug)
    subscriptions = subscribe(root_resource, objective_mappings, socket.assigns.project.slug)

    objectives_tree = to_objective_tree(objective_mappings)
    {:noreply, assign(socket, objective_mappings: objective_mappings, objectives_tree: objectives_tree,
      root_resource: root_resource, subscriptions: subscriptions)}
  end
end
