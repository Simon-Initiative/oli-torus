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

  select_mode:              Which selection mode to operate in. This can be set to :single, :multiple or
                            :container. Defaults to :single
  filter_items_fn:          Filter function applied to items shown. Default is no filter.
  sort_items_fn:            Sorting function applied to items shown. Default is to sort containers first.
  publications:             The list of publications that items can be selected from (used in multi-pub mode)
  selected_publication:     The currently selected publication (used in multi-pub mode)
  active_tab:               The currently selected tab (:curriculum or :all_pages)
  pages_table_model:              The table model containing the ordered and unordered pages
  pages_table_model_params:       The query params for the table model
  pages_table_model_total_count:  The total count for the table model rows
  publications_table_model:              The table model containing the available publications
  publications_table_model_params:       The query params for the publications table model
  publications_table_model_total_count:  The total count for the publications table model rows

  ## Events:
  "HierarchyPicker.update_active", %{"uuid" => uuid}
  "HierarchyPicker.select", %{"uuid" => uuid}
  "HierarchyPicker.select_publication", %{"id" => id}
  "HierarchyPicker.clear_publication", %{"id" => id}
  "HiearachyPicker.HierarchyPicker.update_hierarchy_tab", %{"tab_name" => tab_name}

  """
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias Oli.Resources.Numbering
  alias OliWeb.Common.{Breadcrumb, PagedTable, SearchInput}
  alias Oli.Delivery.Hierarchy.HierarchyNode

  def render(
        %{
          hierarchy: %HierarchyNode{},
          active: %HierarchyNode{children: children}
        } = assigns
      ) do
    assigns = assign(assigns, :children, children)

    ~H"""
    <div id={@id} class="hierarchy-picker">
      <%= if !is_nil(assigns[:selected_publication] || assigns[:active_tab]) do %>
        <.render_back_to_publications />
        <div class="flex mb-2">
          <.render_hierarchy_tab
            tab_name={:curriculum}
            tab_label="Curriculum"
            active_tab={assigns[:active_tab]}
          />
          <.render_hierarchy_tab
            tab_name={:all_pages}
            tab_label="All pages"
            active_tab={assigns[:active_tab]}
          />
        </div>
      <% end %>

      <%= if assigns[:active_tab] == :all_pages do %>
        <form phx-debounce="500" phx-change="HierarchyPicker.pages_text_search" class="ml-auto w-44">
          <SearchInput.render
            text={assigns.pages_table_model_params[:text_search]}
            name="text_search"
            id="text_search"
            placeholder="Search pages"
          />
        </form>
        <PagedTable.render
          total_count={assigns.pages_table_model_total_count}
          filter={assigns.pages_table_model_params.text_filter}
          limit={assigns.pages_table_model_params.limit}
          offset={assigns.pages_table_model_params.offset}
          table_model={
            Map.put(assigns.pages_table_model, :data, %{
              selection: assigns.selection,
              preselected: assigns.preselected,
              selected_publication: assigns.selected_publication
            })
          }
          allow_selection={false}
          sort="HierarchyPicker.pages_sort"
          page_change="HierarchyPicker.pages_page_change"
          show_top_paging={false}
          additional_table_class="remix_materials_table"
          render_top_info={false}
        />
      <% else %>
        <div class="hierarchy-navigation">
          {render_breadcrumb(assigns)}
        </div>
        <div class="hierarchy">
          <%= for child <- @children |> filter_items(assigns) |> sort_items(assigns) do %>
            {render_child(assigns, child)}
          <% end %>
        </div>
      <% end %>
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
        {render_breadcrumb(assigns)}
      </div>
      <div class="hierarchy">
        <form
          phx-debounce="500"
          phx-change="HierarchyPicker.publications_text_search"
          class="ml-auto w-56"
        >
          <SearchInput.render
            text={assigns.publications_table_model_params[:text_search]}
            name="text_search"
            id="text_search"
            placeholder="Search Content Sources"
          />
        </form>
        <PagedTable.render
          total_count={assigns.publications_table_model_total_count}
          filter={assigns.publications_table_model_params.text_filter}
          limit={assigns.publications_table_model_params.limit}
          offset={assigns.publications_table_model_params.offset}
          table_model={assigns.publications_table_model}
          allow_selection={false}
          page_change="HierarchyPicker.publications_page_change"
          show_top_paging={false}
          additional_table_class="remix_materials_publications_table"
          render_top_info={false}
        />
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
    <div
      id={"hierarchy_item_#{@child.uuid}"}
      phx-click="HierarchyPicker.select"
      phx-value-uuid={@child.uuid}
    >
      <div class="flex-1 mx-2">
        <span class="align-middle">
          <input type="checkbox" {@maybe_checked} />
          <OliWeb.Curriculum.Entry.entry_icon child={@child.revision} />
        </span>
        {resource_link(assigns, @child)}
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
    <div id={"hierarchy_item_#{ @child.uuid}"} {@click_handler}>
      <div class="flex-1 mx-2">
        <span class="align-middle">
          <input type="checkbox" {@maybe_checked} {@maybe_preselected} />
          {OliWeb.Curriculum.Entry.entry_icon(%{child: @child.revision})}
        </span>
        {resource_link(assigns, @child)}
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
          {OliWeb.Curriculum.Entry.entry_icon(%{child: @child.revision})}
        </span>
        {resource_link(assigns, @child)}
      </div>
    </div>
    """
  end

  def render_breadcrumb(%{hierarchy: nil, active: nil} = assigns) do
    ~H"""
    <ol class="breadcrumb custom-breadcrumb p-1 px-2">
      <div>
        <button class="btn btn-sm btn-link" disabled>
          <i class="fas fa-book"></i> Select a Content Source
        </button>
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
    <ol class="flex items-center gap-2 bg-gray-100 dark:bg-gray-700 p-2 rounded overflow-x-scroll scrollbar-hide">
      <%= for {breadcrumb, index} <- Enum.with_index(@breadcrumbs) do %>
        <.breadcrumb_item
          breadcrumb={breadcrumb}
          show_short={length(@breadcrumbs) > 3}
          is_first={index == 0}
          is_last={length(@breadcrumbs) - 1 == index}
        />
      <% end %>
    </ol>
    """
  end

  defp breadcrumb_item(assigns) do
    ~H"""
    <li class={"flex gap-2 items-center whitespace-nowrap #{if !@is_last, do: "text-gray-400"}"}>
      <%= case {@is_first, @is_last} do %>
        <% {true, true} -> %>
          <div class="h-6">
            <i class="fa-solid fa-house" />
          </div>
        <% {true, false} -> %>
          <button
            class="btn btn-link p-0"
            phx-click="HierarchyPicker.update_active"
            phx-value-uuid={@breadcrumb.slug}
          >
            <i class="fa-solid fa-house" />
          </button>
          <span>/</span>
        <% {_, true} -> %>
          <span>{get_title(@breadcrumb, @show_short)}</span>
        <% _ -> %>
          <button
            class="btn btn-link p-0"
            disabled={@is_last}
            phx-click="HierarchyPicker.update_active"
            phx-value-uuid={@breadcrumb.slug}
          >
            {get_title(@breadcrumb, @show_short)}
          </button>
          <span>/</span>
      <% end %>
    </li>
    """
  end

  defp render_back_to_publications(assigns) do
    ~H"""
    <button class="btn btn-sm btn-link mr-2" phx-click="HierarchyPicker.clear_publication">
      <i class="fas fa-arrow-left mr-1"></i> Back to publications
    </button>
    """
  end

  defp render_hierarchy_tab(assigns) do
    ~H"""
    <button
      phx-click="HierarchyPicker.update_hierarchy_tab"
      phx-value-tab_name={@tab_name}
      class={"py-3 px-2 border-b-4 #{if @active_tab == @tab_name, do: "border-b-delivery-primary", else: "hover:border-b-4 hover:border-b-delivery-primary/25"}"}
    >
      {@tab_label}
    </button>
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
          <button
            class="btn btn-link entry-title px-0"
            phx-click="HierarchyPicker.update_active"
            phx-value-uuid={@uuid}
          >
            {@title}
          </button>
          """

        _ ->
          ~H"""
          <button class="btn btn-link entry-title px-0" disabled>{@revision.title}</button>
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
        children
    end
  end
end
