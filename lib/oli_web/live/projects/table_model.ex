defmodule OliWeb.Projects.TableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.{Chip, FormatDateTime, SessionContext, Utils}
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(%SessionContext{} = ctx, sections, opts \\ []) do
    default_td_class = "!border-r border-Table-table-border"
    default_th_class = "!border-r border-Table-table-border"
    search_term = Keyword.get(opts, :search_term, "")

    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &custom_render/3,
        td_class: "!sticky left-0 z-[1] bg-inherit " <> default_td_class,
        th_class: "!sticky left-0 z-[60] " <> default_th_class
      },
      %ColumnSpec{
        name: :tags,
        label: "Tags",
        render_fn: &custom_render/3,
        sortable: false,
        td_class: "w-[200px] min-w-[200px] max-w-[200px] !p-0 " <> default_td_class,
        th_class: "w-[200px] min-w-[200px] max-w-[200px] " <> default_th_class
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
    sort_order = Keyword.get(opts, :sort_order, :desc)

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
        ctx: ctx,
        search_term: search_term
      }
    )
  end

  # Title
  def custom_render(assigns, project, %ColumnSpec{name: :title}) do
    assigns =
      assigns
      |> Map.put_new(:search_term, Map.get(assigns, :search_term, ""))
      |> Map.merge(%{project: project})

    ~H"""
    <div class="flex flex-col">
      <a
        href={~p"/workspaces/course_author/#{@project.slug}/overview"}
        class="text-Text-text-link text-base font-medium leading-normal"
      >
        {highlight_search_term(@project.title, @search_term)}
      </a>
      <span class="text-Text-text-low text-sm font-normal leading-tight">
        ID: {highlight_search_term(@project.slug, @search_term)}
      </span>
    </div>
    """
  end

  # Tags
  def custom_render(assigns, project, %ColumnSpec{name: :tags}) do
    assigns = Map.merge(assigns, %{project: project})

    ~H"""
    <div>
      <.live_component
        module={OliWeb.Live.Components.Tags.TagsComponent}
        id={"tags-#{@project.id}"}
        entity_type={:project}
        entity_id={@project.id}
        current_tags={Map.get(@project, :tags, [])}
      />
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
    assigns =
      assigns
      |> Map.put_new(:search_term, Map.get(assigns, :search_term, ""))
      |> Map.merge(%{project: project})

    case project.owner_id do
      nil ->
        ""

      _ ->
        ~H"""
        <a
          href={~p"/admin/authors/#{@project.owner_id}"}
          class="text-Text-text-link text-base font-medium leading-normal"
        >
          {highlight_search_term(@project.name, @search_term)}
        </a>
        <small class="text-Text-text-low text-xs font-semibold leading-3">
          {highlight_search_term(@project.email, @search_term)}
        </small>
        """
    end
  end

  # Collaborators
  def custom_render(assigns, project, %ColumnSpec{name: :collaborators}) do
    assigns =
      assigns
      |> Map.put_new(:search_term, Map.get(assigns, :search_term, ""))
      |> Map.merge(%{project: project})

    ~H"""
    <div>
      <%= for {collab, index} <- Enum.with_index(@project.collaborators || []) do %>
        <a
          href={~p"/admin/authors/#{collab["id"]}"}
          class="text-Text-text-link text-base font-medium leading-normal"
        >
          {highlight_search_term(collab["name"], @search_term)}
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

  defp highlight_search_term(text, search_term),
    do:
      Phoenix.HTML.raw(
        Utils.multi_highlight_search_term(
          text || "",
          search_term,
          "span class=\"search-highlight\"",
          "span"
        )
      )
end
