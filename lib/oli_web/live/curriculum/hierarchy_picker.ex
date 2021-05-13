defmodule OliWeb.Curriculum.HierarchyPicker do
  @moduledoc """
  Hierarchy Picker Component

  A general purpose curriculum location picker. When a new location is selected,
  this component will trigger an "update_selection" event to the parent liveview
  with the new selection.

  Example:
  ```
  def handle_event("HierarchyPicker.select", %{"slug" => slug}, socket) do
    ...
  end
  ```
  """
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias Oli.Resources.Numbering

  def render(assigns) do
    ~L"""
    <div id="hierarchy-picker" class="hierarchy-picker">
      <div class="hierarchy-navigation">
        <%= render_breadcrumb assigns, @breadcrumbs %>
      </div>
      <div class="hierarchy">
        <div class="text-center text-secondary mt-2">
        <b><%= @revision.title %></b> will be placed here
        </div>
        <%# filter out the item being moved from the options, sort all containers first  %>
        <%= for child <- @children |> Enum.filter(&(&1.id != @revision.id)) |> Enum.sort(&sort_containers_first/2) do %>

          <div id="hierarchy_item_<%= child.resource_id %>"
            phx-click="select"
            phx-value-slug="<%= child.slug %>">
            <div class="flex-1">
              <%= OliWeb.Curriculum.EntryLive.icon(%{child: child}) %>
              <%= resource_link assigns, child %>
            </div>
          </div>

        <% end %>
      </div>
    </div>
    """
  end

  def render_breadcrumb(assigns, breadcrumbs) do
    ~L"""
      <ol class="breadcrumb custom-breadcrumb p-1 px-2">
          <button class="btn btn-sm btn-link" phx-click="HierarchyPicker.select" phx-value-slug="<%= previous_slug(breadcrumbs) %>"><i class="las la-arrow-left"></i></button>


        <%= for {breadcrumb, index} <- Enum.with_index(breadcrumbs) do %>
          <%= render_breadcrumb_item Enum.into(%{
            breadcrumb: breadcrumb,
            show_short: length(breadcrumbs) > 3,
            is_last: length(breadcrumbs) - 1 == index,
           }, assigns) %>
        <% end %>
      </ol>
    """
  end

  defp render_breadcrumb_item(
         %{breadcrumb: breadcrumb, show_short: show_short, is_last: is_last} = assigns
       ) do
    ~L"""
    <li class="breadcrumb-item align-self-center">
      <button class="btn btn-xs btn-link px-0" <%= if is_last, do: "disabled" %> phx-click="HierarchyPicker.select" phx-value-slug="<%= breadcrumb.slug %>">
        <%= get_title(breadcrumb, show_short) %>
      </button>
    </li>
    """
  end

  defp get_title(breadcrumb, true = _show_short), do: breadcrumb.short_title
  defp get_title(breadcrumb, false = _show_short), do: breadcrumb.full_title

  defp resource_link(%{numberings: numberings} = assigns, revision) do
    with resource_type <- Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
      case resource_type do
        "container" ->
          numbering = Map.get(numberings, revision.id)

          title =
            if numbering do
              Numbering.prefix(numbering) <> ": " <> revision.title
            else
              revision.title
            end

          ~L"""
            <button class="btn btn-link ml-1 mr-1 entry-title" phx-click="HierarchyPicker.select" phx-value-slug="<%= revision.slug %>">
              <%= title %>
            </button>
          """

        _ ->
          ~L"""
            <button class="btn btn-link ml-1 mr-1 entry-title" disabled><%= revision.title %></button>
          """
      end
    end
  end

  defp sort_containers_first(a, b) do
    case {
      Oli.Resources.ResourceType.get_type_by_id(a.resource_type_id),
      Oli.Resources.ResourceType.get_type_by_id(b.resource_type_id)
    } do
      {"container", "container"} -> true
      {"container", _} -> true
      _ -> false
    end
  end

  defp previous_slug(breadcrumbs) do
    previous = Enum.at(breadcrumbs, length(breadcrumbs) - 2)
    previous.slug
  end
end
