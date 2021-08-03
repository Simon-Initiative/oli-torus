defmodule OliWeb.Objectives.Objectives do
  @moduledoc """
  LiveView implementation of an objective editor.
  """

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Authoring.Editing.ObjectiveEditor
  alias OliWeb.Objectives.ObjectiveEntry
  alias OliWeb.Objectives.CreateNew
  alias OliWeb.Objectives.Attachments
  alias OliWeb.Objectives.BreakdownModal
  alias OliWeb.Common.ManualModal
  alias Oli.Publishing.ObjectiveMappingTransfer
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Repo
  alias Oli.Authoring.Broadcaster.Subscriber
  alias OliWeb.Common.Breadcrumb

  @default_attachment_summary %{attachments: {[], []}, locked_by: %{}, parent_pages: %{}}

  def mount(params, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(Map.get(params, "project_id"))

    objective_mappings = ObjectiveEditor.fetch_objective_mappings(project)

    subscriptions = subscribe(objective_mappings, project.slug)

    objectives_tree = to_objective_tree(objective_mappings)

    {:ok,
     assign(socket,
       active: :objectives,
       objective_mappings: objective_mappings,
       objectives_tree: objectives_tree,
       breadcrumbs: [Breadcrumb.new(%{full_title: "Objectives"})],
       changeset: Resources.change_revision(%Revision{}),
       project: project,
       subscriptions: subscriptions,
       attachment_summary: @default_attachment_summary,
       modal_shown: :none,
       author: author,
       force_render: 0,
       can_delete?: true,
       edit: :none,
       breakdown: :none
     )}
  end

  def render(assigns) do
    ~L"""
    <div class="objectives container mt-5">
      <div class="mb-2 row">
        <div class="col-12">
          <p>
            Learning objectives help you to organize course content and determine appropriate assessments and instructional strategies.
            <br/>Refer to the <a href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html" target="_blank">CMU Eberly Center guide on learning objectives</a> to learn more about the importance of attaching learning objectives to pages and activities.
          </p>
        </div>
      </div>

      <%= live_component CreateNew, changeset: @changeset, project: @project %>

      <hr class="my-4" />

      <%= if Enum.count(@objective_mappings) == 0 do %>
        <div class="mt-3 row">
          <div class="col-12">
            <p>This project has no objectives</p>
          </div>
        </div>
      <% else %>

        <div class="mt-3">
          <%= for {objective_tree, index} <- Enum.with_index(@objectives_tree) do %>
            <%= live_component ObjectiveEntry, changeset: @changeset, objective_mapping: objective_tree.mapping,
              children: objective_tree.children, depth: 1, index: index, project: @project, edit: @edit, breakdown: @breakdown, can_delete?: @can_delete? %>
          <% end %>
        </div>

      <% end %>

    </div>

    <%= case @modal_shown do %>
      <% :delete -> %>
        <%= live_component ManualModal, title: "Delete Objective", modal_id: "deleteModal", ok_action: "delete", ok_label: "Delete", ok_style: "btn-danger confirm" do %>
          <%= live_component Attachments, attachment_summary: @attachment_summary, project: @project %>
        <% end %>
      <% :breakdown -> %>
        <%= live_component BreakdownModal, changeset: @changeset, slug: @breakdown %>
      <% :none -> %>

    <% end %>

    """
  end

  defp to_objective_tree(objective_mappings) do
    if Enum.empty?(objective_mappings) do
      []
    else
      # Extract all children references from objectives
      children_list =
        objective_mappings
        |> Enum.map(fn mapping -> mapping.revision.children end)
        |> Enum.reduce(fn children, acc -> children ++ acc end)

      # Build flat ObjectiveMappingTransfer map for all objectives
      mapping_obs =
        objective_mappings
        |> Enum.reduce(%{}, fn mapping, acc ->
          Map.merge(acc, %{
            mapping.resource.id => %ObjectiveMappingTransfer{mapping: mapping, children: []}
          })
        end)

      # Build nested tree structure
      Enum.reduce(objective_mappings, [], fn m, acc ->
        a = Map.get(mapping_obs, m.resource.id)

        a = %{
          a
          | children:
              m.revision.children
              |> Enum.reduce(a.children, fn c, mc ->
                val = Map.get(mapping_obs, c)

                if is_nil(val) do
                  mc
                else
                  [val] ++ mc
                end
              end)
        }

        if !Enum.member?(children_list, m.resource.id) do
          acc ++ [a]
        else
          acc
        end
      end)
      |> Enum.sort(fn e1, e2 ->
        e1.mapping.resource.inserted_at <= e2.mapping.resource.inserted_at
      end)
    end
  end

  # spin up subscriptions for the container and for all of its objectives
  defp subscribe(objective_mappings, project_slug) do
    ids = Enum.map(objective_mappings, fn p -> p.resource.id end)
    Enum.each(ids, &Subscriber.subscribe_to_new_revisions_in_project(&1, project_slug))

    Subscriber.subscribe_to_new_resources_of_type(
      ResourceType.get_id_by_type("objective"),
      project_slug
    )

    ids
  end

  # release a collection of subscriptions
  defp unsubscribe(ids, project_slug) do
    Subscriber.unsubscribe_to_new_resources_of_type(
      ResourceType.get_id_by_type("objective"),
      project_slug
    )

    Enum.each(ids, &Subscriber.unsubscribe_to_new_revisions_in_project(&1, project_slug))
  end

  # handle change of edit
  def handle_event("modify", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, :edit, slug)}
  end

  def handle_event("add_sub", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, :edit, slug)}
  end

  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, edit: :none, breakdown: :none, modal_shown: :none)}
  end

  # handle any cancel events a modal might generate from being closed
  def handle_event("cancel_modal", params, socket), do: handle_event("cancel", params, socket)

  # process form submission to save page settings
  def handle_event("edit", %{"revision" => objective_params}, socket) do
    with_atom_keys =
      Map.keys(objective_params)
      |> Enum.reduce(%{}, fn k, m ->
        Map.put(m, String.to_existing_atom(k), Map.get(objective_params, k))
      end)

    socket =
      case ObjectiveEditor.edit(
             Map.get(with_atom_keys, :slug),
             with_atom_keys,
             socket.assigns.author,
             socket.assigns.project
           ) do
        {:ok, _} ->
          socket

        {:error, _} ->
          socket
          |> put_flash(:error, "Could not edit objective")
      end

    {:noreply, assign(socket, :edit, :none)}
  end

  def handle_event("prepare_delete", %{"slug" => slug}, socket) do
    if socket.assigns.can_delete? do
      %{resource_id: resource_id} =
        AuthoringResolver.from_revision_slug(socket.assigns.project.slug, slug)

      attachment_summary =
        ObjectiveEditor.preview_objective_detatchment(resource_id, socket.assigns.project)

      {:noreply,
       assign(socket,
         modal_shown: :delete,
         attachment_summary: attachment_summary,
         prepare_delete_slug: slug,
         force_render: socket.assigns.force_render + 1
       )}
    else
      {:noreply, socket}
    end
  end

  # handle processing deletion of item
  def handle_event("delete", _, socket) do
    %{resource_id: resource_id} =
      AuthoringResolver.from_revision_slug(
        socket.assigns.project.slug,
        socket.assigns.prepare_delete_slug
      )

    ObjectiveEditor.detach_objective(resource_id, socket.assigns.project, socket.assigns.author)

    parent_objective = determine_parent_objective(socket, socket.assigns.prepare_delete_slug)

    socket =
      case ObjectiveEditor.preview_objective_detatchment(resource_id, socket.assigns.project) do
        %{attachments: {[], []}} ->
          case ObjectiveEditor.delete(
                 socket.assigns.prepare_delete_slug,
                 socket.assigns.author,
                 socket.assigns.project,
                 parent_objective
               ) do
            {:ok, _} ->
              socket

            {:error, _} ->
              socket
              |> put_flash(:error, "Could not remove objective")
          end

        _ ->
          socket
      end

    {:noreply, assign(socket, modal_shown: :none)}
  end

  def handle_event("breakdown", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, breakdown: slug, modal_shown: :breakdown)}
  end

  # handle clicking of the add objective
  def handle_event("perform_breakdown", %{"revision" => objective_params}, socket) do
    with_atom_keys =
      Map.keys(objective_params)
      |> Enum.reduce(%{}, fn k, m ->
        Map.put(m, String.to_existing_atom(k), Map.get(objective_params, k))
      end)

    slug = Map.get(objective_params, "slug")

    socket =
      case ObjectiveEditor.add_new_parent_for_objective(
             with_atom_keys,
             socket.assigns.author,
             socket.assigns.project,
             slug
           ) do
        {:ok, _} ->
          socket

        {:error, %Ecto.Changeset{} = _changeset} ->
          socket
          |> put_flash(:error, "Could not break down objective")
      end

    {:noreply, assign(socket, breakdown: :none, modal_shown: :none)}
  end

  # handle clicking of the add objective
  def handle_event("new", %{"revision" => objective_params}, socket) do
    with_atom_keys =
      Map.keys(objective_params)
      |> Enum.reduce(%{}, fn k, m ->
        Map.put(m, String.to_existing_atom(k), Map.get(objective_params, k))
      end)

    container_slug = Map.get(objective_params, "parent_slug")

    socket =
      case ObjectiveEditor.add_new(
             with_atom_keys,
             socket.assigns.author,
             socket.assigns.project,
             container_slug
           ) do
        {:ok, _} ->
          socket

        {:error, %Ecto.Changeset{} = _changeset} ->
          socket
          |> put_flash(:error, "Could not create objective")
      end

    {:noreply, assign(socket, edit: :none, changeset: Resources.change_revision(%Revision{}))}
  end

  defp determine_parent_objective(socket, slug) do
    child =
      Enum.find(socket.assigns.objective_mappings, fn %{revision: revision} ->
        revision.slug == slug
      end)

    case Enum.find(socket.assigns.objectives_tree, fn %{mapping: mapping} ->
           Enum.any?(mapping.revision.children, fn id -> id == child.revision.resource_id end)
         end) do
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
    objective_mappings =
      if any == :added do
        ObjectiveEditor.fetch_objective_mappings(socket.assigns.project)
      else
        # on just an objective change, update the revision in place
        case Enum.find_index(socket.assigns.objective_mappings, fn p -> p.resource.id == id end) do
          nil ->
            socket.assigns.objective_mappings

          index ->
            case revision.deleted do
              false ->
                mapping = %{
                  Enum.at(socket.assigns.objective_mappings, index)
                  | revision: revision
                }

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

    {:noreply,
     assign(socket,
       objective_mappings: objective_mappings,
       objectives_tree: objectives_tree,
       subscriptions: subscriptions
     )}
  end
end
