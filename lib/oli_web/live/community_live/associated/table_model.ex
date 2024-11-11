defmodule OliWeb.CommunityLive.Associated.TableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias Oli.Groups.CommunityVisibility
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def get_field(field, association) do
    case association do
      %CommunityVisibility{project: project, section: nil} -> Map.get(project, field)
      %CommunityVisibility{project: nil, section: section} -> Map.get(section, field)
      association -> Map.get(association, field)
    end
  end

  def new(associations, ctx, id_field \\ :unique_id, action \\ "select") do
    action =
      case action do
        "select" -> &__MODULE__.render_select_column/3
        "remove" -> &__MODULE__.render_remove_column/3
      end

    SortableTableModel.new(
      rows: associations,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &__MODULE__.render_title_column/3,
          sort_fn: &__MODULE__.sort_title_column/2
        },
        %ColumnSpec{
          name: :type,
          label: "Type",
          render_fn: &__MODULE__.render_type_column/3
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &Common.render_date/3
        },
        %ColumnSpec{
          name: :action,
          label: "Action",
          render_fn: action
        }
      ],
      event_suffix: "",
      id_field: [id_field],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_title_column(assigns, item, _) do
    case item.unique_type do
      "product" ->
        route_path =
          Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, get_field(:slug, item))

        SortableTableModel.render_link_column(assigns, get_field(:title, item), route_path)

      "project" ->
        route_path = ~p"/workspaces/course_author/#{get_field(:slug, item)}/overview"

        SortableTableModel.render_link_column(assigns, get_field(:title, item), route_path)
    end
  end

  def sort_title_column(sort_order, _sort_spec),
    do: {fn t -> get_field(:title, t) end, sort_order}

  def render_select_column(assigns, item, _) do
    assigns = Map.merge(assigns, %{item: item})

    ~H"""
    <button
      class="btn btn-primary"
      phx-click="select"
      phx-value-type={@item.unique_type}
      phx-value-id={@item.id}
    >
      Select
    </button>
    """
  end

  def render_remove_column(assigns, item, _) do
    assigns = Map.merge(assigns, %{item: item})

    ~H"""
    <button class="btn btn-primary" phx-click="remove" phx-value-id={@item.id}>Remove</button>
    """
  end

  def render_type_column(_, item, _) do
    case item.unique_type do
      "product" -> "Product"
      "project" -> "Project"
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
