defmodule OliWeb.Common.Hierarchy.HierarchyPicker do
  @moduledoc """
  Hierarchy Picker Component

  A general purpose curriculum location picker. When a new location is selected,
  this component will trigger an "HierarchyPicker.update_selection" event to the parent liveview
  with the new selection.

  ### Multi-Pub Mode

  In multi-pub mode, a user can select items from multiple publications. The active hierarchy shown
  is still dictated by the hierarchy and active parameters, but this hierarchy is expected to change,
  specifically when the "HierarchyPicker.select_publication" event is triggered. The liveview using this
  component should handle this event and update hierarchy accordingly.

  ## Required Parameters:

  id:               Unique identifier for the hierarchy picker
  hierarchy:        Hierarchy to select from
  active:           Currently active node. Also represents the current selection in container
                    selection mode.
  selection:        List of current selections in the form of a tuples [{publication_id, resource_id}, ...].
                    (Only used in multi select mode)
  preselected:      List of preselected items which are already selected and cannot be changed. Like selection,
                    the list is expected to be in the form of a tuples [{publication_id, resource_id}, ...]

  ## Optional Parameters:

  select_mode:            Which selection mode to operate in. This can be set to :single, :multiple or
                          :container. Defaults to :single
  filter_items_fn:        Filter function applied to items shown. Default is no filter.
  sort_items_fn:          Sorting function applied to items shown. Default is to sort containers first.
  publications:           The list of publications that items can be selected from (used in multi-pub mode)
  selected_publication:   The currently selected publication (used in multi-pub mode)

  ## Events:
  "HierarchyPicker.update_active", %{"uuid" => uuid}
  "HierarchyPicker.select", %{"uuid" => uuid}
  "HierarchyPicker.select_publication", %{"id" => id}
  "HierarchyPicker.clear_publication", %{"id" => id}

  """
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias Oli.Resources.Numbering
  alias OliWeb.Common.Breadcrumb
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Publishing.Publications.Publication
  alias Oli.Authoring.Course.Project

  def render(
        %{
          hierarchy: %HierarchyNode{},
          active: %HierarchyNode{children: children}
        } = assigns
      ) do
    assigns = assign(assigns, :children, children)

    ~H"""
    <div id={@id} class="hierarchy-picker">
      <div class="hierarchy-navigation">
        <%= render_breadcrumb assigns %>
      </div>
      <div class="hierarchy">
        <%# filter out the item being moved from the options, sort all containers first  %>
        <%= for child <- @children |> filter_items(assigns) |> sort_items(assigns) do %>
          <%= render_child(assigns, child) %>
        <% end %>
      </div>
    </div>
    """
  end

  def render(
        %{
          hierarchy: nil,
          active: nil
        } = assigns
      ) do
    ~H"""
    <div id={@id} class="hierarchy-picker">
      <div class="hierarchy-navigation">
        <%= render_breadcrumb assigns %>
      </div>
      <div class="hierarchy">
        <%= for pub <- @publications do %>

          <div id={"hierarchy_item_#{pub.id}"}>
            <button class="btn btn-link ml-1 mr-1 entry-title" phx-click="HierarchyPicker.select_publication" phx-value-id={pub.id}>
              <%= pub.project.title %>
            </button>
          </div>

        <% end %>
      </div>
    </div>
    """
  end

  def render_child(
        %{
          select_mode: :single,
          selection: selection
        } = assigns,
        child
      ) do
    assigns =
      assigns
      |> assign(:maybe_checked, maybe_checked(selection, child.uuid))
      |> assign(:child, child)

    ~H"""
    <div id={"hierarchy_item_#{@child.uuid}"} phx-click="HierarchyPicker.select" phx-value-uuid={@child.uuid}>
      <div class="flex-1 mx-2">
        <span class="align-middle">
          <input type="checkbox" {@maybe_checked} />
          <OliWeb.Curriculum.EntryLive.icon child={@child.revision} />
        </span>
        <%= resource_link assigns, @child %>
      </div>
    </div>
    """
  end

  def render_child(
        %{
          select_mode: :multiple,
          selection: selection,
          preselected: preselected,
          selected_publication: pub
        } = assigns,
        child
      ) do
    assigns =
      assigns
      |> assign(:child, child)
      |> assign(
        :click_handler,
        if {pub.id, child.revision.resource_id} in preselected do
          []
        else
          ["phx-click": "HierarchyPicker.select", "phx-value-uuid": child.uuid]
        end
      )
      |> assign(:maybe_checked, maybe_checked(selection, pub.id, child.revision.resource_id))
      |> assign(
        :maybe_preselected,
        maybe_preselected(preselected, pub.id, child.revision.resource_id)
      )

    ~H"""
    <div id={"hierarchy_item_#{ @child.uuid}"} {@click_handler} >
      <div class="flex-1 mx-2">
        <span class="align-middle">
          <input type="checkbox" {@maybe_checked} {@maybe_preselected} />
          <%= OliWeb.Curriculum.EntryLive.icon(%{child:  @child.revision}) %>
        </span>
        <%= resource_link assigns,  @child %>
      </div>
    </div>
    """
  end

  def render_child(assigns, child) do
    assigns = assign(assigns, :child, child)

    ~H"""
    <div id={"hierarchy_item_#{@child.uuid}"}>
      <div class="flex-1 mx-2">
        <span class="align-middle">
          <%= OliWeb.Curriculum.EntryLive.icon(%{child: @child.revision}) %>
        </span>
        <%= resource_link assigns, @child %>
      </div>
    </div>
    """
  end

  def render_breadcrumb(%{hierarchy: nil, active: nil} = assigns) do
    ~H"""
      <ol class="breadcrumb custom-breadcrumb p-1 px-2">
        <div>
          <button class="btn btn-sm btn-link" disabled><i class="fas fa-book"></i> Select a Publication</button>
        </div>
      </ol>
    """
  end

  def render_breadcrumb(%{hierarchy: hierarchy, active: active} = assigns) do
    breadcrumbs = Breadcrumb.breadcrumb_trail_to(hierarchy, active)

    assigns =
      assigns
      |> assign(:breadcrumbs, breadcrumbs)
      |> assign(:maybe_disabled, maybe_disabled(breadcrumbs))

    ~H"""
      <ol class="breadcrumb custom-breadcrumb p-1 px-2">
        <%= case assigns[:selected_publication] do %>
          <% nil -> %>

          <% selected_publication -> %>
            <div class="border-right border-light">
              <button class="btn btn-sm btn-link mr-2" phx-click="HierarchyPicker.clear_publication"><i class="fas fa-book"></i> <%= publication_title(selected_publication) %></button>
            </div>
        <% end %>

        <button class="btn btn-sm btn-link" {@maybe_disabled} phx-click="HierarchyPicker.update_active" phx-value-uuid={previous_uuid(@breadcrumbs)}><i class="fas fa-arrow-left"></i></button>

        <%= for {breadcrumb, index} <- Enum.with_index(@breadcrumbs) do %>
          <.breadcrumb_item
            breadcrumb={breadcrumb}
            show_short={length(@breadcrumbs) > 3}
            is_last={length(@breadcrumbs) - 1 == index} />
        <% end %>
      </ol>
    """
  end

  defp breadcrumb_item(assigns) do
    ~H"""
    <li class="breadcrumb-item self-center pl-2">
      <button class="btn btn-xs btn-link px-0" disabled={@is_last} phx-click="HierarchyPicker.update_active" phx-value-uuid={@breadcrumb.slug}>
        <%= get_title(@breadcrumb, @show_short) %>
      </button>
    </li>
    """
  end

  defp maybe_checked(selection, pub_id, resource_id) do
    if {pub_id, resource_id} in selection do
      [checked: true]
    else
      []
    end
  end

  defp maybe_checked(selection, uuid) do
    if uuid == selection do
      [checked: true]
    else
      []
    end
  end

  defp maybe_preselected(preselected, pub_id, resource_id) do
    if {pub_id, resource_id} in preselected do
      [checked: true, disabled: true]
    else
      []
    end
  end

  defp maybe_disabled(breadcrumbs) do
    if Enum.count(breadcrumbs) < 2, do: [disabled: true], else: []
  end

  defp get_title(breadcrumb, true = _show_short), do: breadcrumb.short_title
  defp get_title(breadcrumb, false = _show_short), do: breadcrumb.full_title

  defp publication_title(%Publication{project: %Project{title: title}}) do
    if String.length(title) > 16 do
      String.slice(title, 0, 16) <> "..."
    else
      title
    end
  end

  defp resource_link(assigns, %HierarchyNode{
         uuid: uuid,
         revision: revision,
         numbering: numbering
       }) do
    assigns =
      assigns
      |> assign(:uuid, uuid)
      |> assign(:revision, revision)
      |> assign(:numbering, numbering)

    with resource_type <- Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
      case resource_type do
        "container" ->
          assigns =
            assigns
            |> assign(
              :title,
              if numbering do
                Numbering.prefix(numbering) <> ": " <> revision.title
              else
                revision.title
              end
            )

          ~H"""
            <button class="btn btn-link entry-title px-0" phx-click="HierarchyPicker.update_active" phx-value-uuid={@uuid}>
              <%= @title %>
            </button>
          """

        _ ->
          ~H"""
            <button class="btn btn-link entry-title px-0" disabled><%= @revision.title %></button>
          """
      end
    end
  end

  defp filter_items(children, assigns) do
    case assigns do
      %{filter_items_fn: filter_items_fn} when filter_items_fn != nil ->
        filter_items_fn.(children)

      _ ->
        # no filter
        children
    end
  end

  defp sort_items(children, assigns) do
    case assigns do
      %{sort_items_fn: sort_items_fn} when sort_items_fn != nil ->
        sort_items_fn.(children)

      _ ->
        # default sort by resource type, containers first
        Enum.sort(children, &sort_containers_first/2)
    end
  end

  defp sort_containers_first(%HierarchyNode{revision: a}, %HierarchyNode{revision: b}) do
    case {
      Oli.Resources.ResourceType.get_type_by_id(a.resource_type_id),
      Oli.Resources.ResourceType.get_type_by_id(b.resource_type_id)
    } do
      {"container", _} -> true
      {type_a, type_b} when type_a == type_b -> true
      _ -> false
    end
  end

  defp previous_uuid(breadcrumbs) do
    previous = Enum.at(breadcrumbs, length(breadcrumbs) - 2)
    previous.slug
  end
end
