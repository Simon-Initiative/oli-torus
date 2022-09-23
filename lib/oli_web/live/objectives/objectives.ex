defmodule OliWeb.Objectives.Objectives do
  @moduledoc """
  LiveView implementation of an objective editor.
  """

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Authoring.Editing.ObjectiveEditor

  alias OliWeb.Objectives.{
    ObjectiveEntry,
    CreateNew,
    DeleteModal,
    SelectionsModal,
    BreakdownModal,
    SelectExistingSubModal
  }

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
       modal: nil,
       author: author,
       force_render: 0,
       can_delete?: true,
       edit: :none,
       title: "Objectives | " <> project.title
     )}
  end

  def render(assigns) do
    ~L"""
    <%= render_modal(assigns) %>

    <div class="objectives container">
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
              children: objective_tree.children, depth: 1, index: index, project: @project, edit: @edit, can_delete?: @can_delete? %>
          <% end %>
        </div>

      <% end %>

    </div>
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
        e1.mapping.resource.inserted_at >= e2.mapping.resource.inserted_at
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
    {:noreply, assign(socket, edit: :none)}
  end

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

  def handle_event("show_delete_modal", %{"slug" => slug}, socket) do
    %{can_delete?: can_delete?, project: project, force_render: force_render} = socket.assigns

    if can_delete? do
      publication_id = Oli.Publishing.get_unpublished_publication_id!(project.id)
      %{resource_id: resource_id} = AuthoringResolver.from_revision_slug(project.slug, slug)

      case Oli.Publishing.find_objective_in_selections(resource_id, publication_id) do
        [] ->
          attachment_summary = ObjectiveEditor.preview_objective_detatchment(resource_id, project)

          {:noreply,
           assign(socket,
             modal: %{
               component: DeleteModal,
               assigns: %{
                 id: "delete_objective_modal",
                 slug: slug,
                 project: project,
                 attachment_summary: attachment_summary,
                 force_render: force_render + 1
               }
             }
           )}

        selections ->
          {:noreply,
           assign(socket,
             modal: %{
               component: SelectionsModal,
               assigns: %{
                 id: "selections_modal",
                 selections: selections,
                 project_slug: project.slug,
                 force_render: force_render + 1
               }
             }
           )}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_select_existing_sub_modal", %{"slug" => slug}, socket) do
    # TO DO: refactor to less iterations
    click_objective =
      Enum.find(socket.assigns.objectives_tree, fn objective -> objective.mapping.revision.slug == slug end)

    sub_objectives = Enum.reduce(socket.assigns.objectives_tree, [], fn parent_objective, sub_objectives ->
      if parent_objective.mapping.revision.slug != slug do
        Enum.reduce(parent_objective.children, sub_objectives, fn child, sub_objectives ->
          in_sub_objectives =
            Enum.find(sub_objectives, fn sub_objective -> sub_objective.mapping.revision.slug == child.mapping.revision.slug end)
          in_parent_chidren =
            Enum.find(click_objective.children, fn click_children -> click_children.mapping.revision.slug == child.mapping.revision.slug end)

          case {in_sub_objectives, in_parent_chidren} do
            {nil, nil} -> [child | sub_objectives]
            _ -> sub_objectives
          end
        end)
      else
        sub_objectives
      end
    end)

    {:noreply,
      assign(socket,
        modal: %{
          component: SelectExistingSubModal,
          assigns: %{
            id: "select_existing_sub_modal",
            parent_slug: slug,
            sub_objectives: sub_objectives,
            add: "add_existing_sub"
          }
        }
      )}
  end

  def handle_event("add_existing_sub", %{"slug" => slug, "parent_slug" => parent_slug} = _params, socket) do
    %{project: project, author: author} = socket.assigns

    socket = case ObjectiveEditor.add_new_parent_for_sub_objective(
        slug,
        parent_slug,
        project.slug,
        author
      ) do
      {:ok, _revision} -> put_flash(socket, :info, "Sub-objective successfully added")
      _ -> put_flash(socket, :error, "Could not add sub-objective")
    end

    {:noreply, hide_modal(socket)}
  end

  # handle processing deletion of item
  def handle_event("delete", %{"slug" => slug}, socket) do
    %{project: project, author: author} = socket.assigns

    %{resource_id: resource_id} =
      AuthoringResolver.from_revision_slug(
        project.slug,
        slug
      )

    ObjectiveEditor.detach_objective(resource_id, project, author)

    parent_objective = determine_parent_objective(socket, slug)

    socket =
      case ObjectiveEditor.preview_objective_detatchment(resource_id, project) do
        %{attachments: {[], []}} ->
          case ObjectiveEditor.delete(
                 slug,
                 author,
                 project,
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

    {:noreply, hide_modal(socket)}
  end

  def handle_event("show_breakdown_modal", %{"slug" => slug}, socket) do
    %{changeset: changeset} = socket.assigns

    modal = %{
      component: BreakdownModal,
      assigns: %{
        id: "breakdown_objective",
        slug: slug,
        changeset: changeset
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  # handle clicking of the add objective
  def handle_event("breakdown", %{"revision" => objective_params}, socket) do
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

    {:noreply, hide_modal(socket)}
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
