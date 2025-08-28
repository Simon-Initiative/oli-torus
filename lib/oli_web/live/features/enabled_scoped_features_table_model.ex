defmodule OliWeb.Features.EnabledScopedFeaturesTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(features) do
    SortableTableModel.new(
      rows: features,
      column_specs: [
        %ColumnSpec{
          name: :feature_name,
          label: "Feature Name",
          render_fn: &render_feature_name_column/3
        },
        %ColumnSpec{
          name: :resource_type,
          label: "Resource Type",
          render_fn: &render_resource_type_column/3
        },
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &render_title_column/3,
          sortable: false,
          sort_fn: &sort_by_title/2
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Enabled Date",
          render_fn: &render_enabled_date_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{}
    )
  end

  def render_feature_name_column(assigns, feature, _) do
    assigns = Map.merge(assigns, %{feature_name: feature.feature_name})

    ~H"""
    <span class="font-medium text-gray-900">
      {@feature_name}
    </span>
    """
  end

  def render_resource_type_column(assigns, feature, _) do
    assigns = Map.merge(assigns, %{resource_type: feature.resource_type})

    ~H"""
    <span class={[
      "px-2 py-1 text-xs rounded-full",
      if(@resource_type == "project",
        do: "bg-blue-100 text-blue-800",
        else: "bg-green-100 text-green-800"
      )
    ]}>
      {String.capitalize(@resource_type)}
    </span>
    """
  end

  def render_title_column(assigns, feature, _) do
    {title, route_path} =
      case feature.resource_type do
        "project" ->
          {feature.project_title, ~p"/workspaces/course_author/#{feature.project_slug}/overview"}

        "section" ->
          {feature.section_title, ~p"/sections/#{feature.section_slug}/manage"}
      end

    assigns = Map.merge(assigns, %{title: title, route_path: route_path})

    ~H"""
    <a href={@route_path} class="text-blue-600 hover:text-blue-800 hover:underline">
      {@title}
    </a>
    """
  end

  def render_enabled_date_column(assigns, feature, _) do
    assigns = Map.merge(assigns, %{inserted_at: feature.inserted_at})

    ~H"""
    <span class="text-sm text-gray-600">
      {Calendar.strftime(@inserted_at, "%Y-%m-%d %H:%M")}
    </span>
    """
  end

  # Custom sort function for title column since it can be either project_title or section_title
  defp sort_by_title(features, :asc) do
    Enum.sort_by(features, fn feature ->
      case feature.resource_type do
        "project" -> feature.project_title || ""
        "section" -> feature.section_title || ""
      end
    end)
  end

  defp sort_by_title(features, :desc) do
    Enum.sort_by(
      features,
      fn feature ->
        case feature.resource_type do
          "project" -> feature.project_title || ""
          "section" -> feature.section_title || ""
        end
      end,
      :desc
    )
  end
end
