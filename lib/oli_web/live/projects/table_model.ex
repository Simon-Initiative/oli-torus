defmodule OliWeb.Projects.TableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.{Chip, FormatDateTime, SessionContext}
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(%SessionContext{} = ctx, sections, opts \\ []) do
    default_td_class = "!border-r border-Table-table-border"
    default_th_class = "!border-r border-Table-table-border"

    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &custom_render/3,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :tags,
        label: "Tags",
        render_fn: &custom_render/3,
        sortable: false,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :inserted_at,
        label: "Created",
        render_fn: &custom_render/3,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :name,
        label: "Created By",
        render_fn: &custom_render/3,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :collaborators,
        label: "Collaborators",
        render_fn: &custom_render/3,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :published,
        label: "Published",
        render_fn: &custom_render/3,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :visibility,
        label: "Visibility",
        render_fn: &custom_render/3,
        td_class: default_td_class,
        th_class: default_th_class
      },
      %ColumnSpec{
        name: :status,
        label: "Status",
        render_fn: &custom_render/3
      }
    ]

    sort_by = Keyword.get(opts, :sort_by_spec, :inserted_at)
    sort_order = Keyword.get(opts, :sort_order, :asc)

    sort_by_spec =
      Enum.find(column_specs, fn spec -> spec.name == sort_by end)

    SortableTableModel.new(
      rows: sections,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      sort_by_spec: sort_by_spec,
      sort_order: sort_order,
      data: %{
        ctx: ctx
      }
    )
  end

  # Title
  def custom_render(assigns, project, %ColumnSpec{name: :title}) do
    assigns = Map.merge(assigns, %{project: project})

    ~H"""
    <div class="flex flex-col">
      <a
        href={~p"/workspaces/course_author/#{@project.slug}/overview"}
        class="text-Text-text-link text-base font-medium leading-normal"
      >
        {@project.title}
      </a>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {@project.slug}
      </span>
    </div>
    """
  end

  # Tags
  def custom_render(assigns, project, %ColumnSpec{name: :tags}) do
    assigns = Map.merge(assigns, %{project: project})

    ~H"""
    <div>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        {@project[:tags] || ""}
      </span>
    </div>
    """
  end

  # Created
  def custom_render(assigns, project, %ColumnSpec{name: :inserted_at}) do
    assigns = Map.merge(assigns, %{project: project})

    ~H"""
    <span class="text-Text-text-high text-base font-medium">
      {FormatDateTime.to_formatted_datetime(
        @project.inserted_at,
        @ctx,
        "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
      )}
    </span>
    """
  end

  # Name
  def custom_render(assigns, project, %ColumnSpec{name: :name}) do
    assigns = Map.merge(assigns, %{project: project})

    case project.owner_id do
      nil ->
        ""

      _ ->
        ~H"""
        <a
          href={~p"/admin/authors/#{@project.owner_id}"}
          class="text-Text-text-link text-base font-medium leading-normal"
        >
          {@project.name}
        </a>
        <small class="text-Text-text-low text-xs font-semibold leading-3">
          {@project.email}
        </small>
        """
    end
  end

  # Collaborators
  def custom_render(assigns, project, %ColumnSpec{name: :collaborators}) do
    assigns = Map.merge(assigns, %{project: project})

    ~H"""
    <div>
      <%= for {collab, index} <- Enum.with_index(@project.collaborators || []) do %>
        <a
          href={~p"/admin/authors/#{collab["id"]}"}
          class="text-Text-text-link text-base font-medium leading-normal"
        >
          {collab["name"]}
        </a>
        <%= if index < length(@project.collaborators) - 1 do %>
          <span class="text-Text-text-high text-base font-medium leading-normal">, </span>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Published
  def custom_render(_assigns, project, %ColumnSpec{name: :published}) do
    case project.published do
      true ->
        SortableTableModel.render_span_column(
          %{},
          "Yes",
          "text-Table-text-accent-green"
        )

      false ->
        SortableTableModel.render_span_column(
          %{},
          "No",
          "text-Table-text-danger"
        )
    end
  end

  # Visibility
  def custom_render(assigns, project, %ColumnSpec{name: :visibility}) do
    {bg_color, text_color} =
      case project.visibility do
        :global -> {"bg-Fill-Accent-fill-accent-teal", "text-Text-text-accent-teal"}
        _ -> {"bg-Fill-Accent-fill-accent-purple", "text-Text-text-accent-purple"}
      end

    assigns =
      Map.merge(assigns, %{
        label: if(project.visibility == :global, do: "Open", else: "Restricted"),
        bg_color: bg_color,
        text_color: text_color
      })

    ~H"""
    <Chip.render {assigns} />
    """
  end

  # Status
  def custom_render(_assigns, project, %ColumnSpec{name: :status}) do
    case project.status do
      :active ->
        SortableTableModel.render_span_column(
          %{},
          "Active",
          "text-Table-text-accent-green"
        )

      :deleted ->
        SortableTableModel.render_span_column(
          %{},
          "Deleted",
          "text-Table-text-danger"
        )
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
