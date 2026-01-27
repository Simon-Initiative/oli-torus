defmodule OliWeb.Workspaces.CourseAuthor.OverviewSectionsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.{SessionContext, Utils}
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}

  def new(%SessionContext{} = ctx, sections) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :section_project_publications,
        label: "Current Publication",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :creator,
        label: "Creator",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :start_date,
        label: "Start Date",
        render_fn: &Common.render_date/3,
        sort_fn: &Common.sort_date/2
      },
      %ColumnSpec{
        name: :end_date,
        label: "End Date",
        render_fn: &Common.render_date/3,
        sort_fn: &Common.sort_date/2
      },
      %ColumnSpec{
        name: :requires_payment,
        label: "Cost",
        render_fn: &custom_render/3
      }
    ]

    SortableTableModel.new(
      rows: sections,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{ctx: ctx}
    )
  end

  def custom_render(assigns, section, %ColumnSpec{name: :title}) do
    assigns = Map.merge(assigns, %{section: section})

    ~H"""
    <a
      href={~p"/sections/#{@section.slug}/manage"}
      class="text-Text-text-link hover:text-Text-text-link hover:underline"
    >
      {@section.title}
    </a>
    """
  end

  def custom_render(assigns, section, %ColumnSpec{name: :section_project_publications}) do
    case section.section_project_publications do
      [first | _] ->
        %{edition: edition, major: major, minor: minor} = first.publication
        assigns = Map.merge(assigns, %{edition: edition, major: major, minor: minor})

        ~H"""
        <span class="badge badge-primary">{Utils.render_version(@edition, @major, @minor)}</span>
        """

      _ ->
        assigns = assigns

        ~H"""
        <span class="text-Text-text-low">N/A</span>
        """
    end
  end

  def custom_render(assigns, section, %ColumnSpec{name: :creator}) do
    case section.creator do
      nil ->
        "N/A"

      "" ->
        "N/A"

      creator ->
        case String.split(creator, "|") do
          [id, given_name, family_name, email] ->
            name = "#{given_name} #{family_name}" |> String.trim()
            # Handle edge case where name is empty (only whitespace)
            display_name = if name == "", do: email, else: name
            assigns = Map.merge(assigns, %{id: id, name: display_name, email: email})

            ~H"""
            <span>
              <a
                href={~p"/admin/users/#{@id}"}
                class="text-Text-text-link hover:text-Text-text-link hover:underline"
              >
                {@name}
              </a>
              <span class="text-Text-text-low">{@email}</span>
            </span>
            """

          _ ->
            # Fallback for unexpected format
            creator
        end
    end
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :requires_payment}) do
    if section.requires_payment do
      case Money.to_string(section.amount) do
        {:ok, m} -> m
        _ -> "Yes"
      end
    else
      "None"
    end
  end
end
