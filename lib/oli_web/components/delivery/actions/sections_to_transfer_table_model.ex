defmodule OliWeb.Delivery.Actions.SectionsToTransferTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime

  def new(sections, target) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "TITLE",
        render_fn: &__MODULE__.render_section_column/3,
        th_class: "pl-10"
      },
      %ColumnSpec{
        name: :start_date,
        label: "START DATE",
        render_fn: &__MODULE__.render_date/3
      },
      %ColumnSpec{
        name: :end_date,
        label: "END DATE",
        render_fn: &__MODULE__.render_date/3
      },
      %ColumnSpec{
        name: :instructor,
        label: "INSTRUCTOR NAME",
        render_fn: &__MODULE__.render_instructors_column/3,
        sortable: false
      }
    ]

    SortableTableModel.new(
      rows: sections,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{target: target}
    )
  end

  def render_section_column(assigns, section, _) do
    assigns = Map.merge(assigns, %{title: section.title, section_id: section.id})

    ~H"""
    <div class="pl-9 pr-4 flex flex-col">
      {@title}
    </div>
    """
  end

  def render_date(assigns, section, %ColumnSpec{name: :start_date}) do
    assigns = Map.put(assigns, :start_date, section.start_date)

    ~H"""
    {FormatDateTime.format_datetime(@start_date, show_timezone: false)}
    """
  end

  def render_date(assigns, section, %ColumnSpec{name: :end_date}) do
    assigns = Map.put(assigns, :end_date, section.end_date)

    ~H"""
    {FormatDateTime.format_datetime(@end_date, show_timezone: false)}
    """
  end

  def render_instructors_column(assigns, section, %ColumnSpec{name: :instructor}) do
    names = Enum.map(section.instructors, & &1.name)
    names_count = length(names)

    instructors =
      case names_count do
        0 ->
          "-"

        1 ->
          hd(names)

        2 ->
          Enum.join(names, " , ")

        _ ->
          first_three_names = Enum.take(names, 3)
          rest_count = names_count - 3

          first_three_names_str = Enum.join(first_three_names, ", ")

          others_str =
            "and #{rest_count} more #{if rest_count == 1, do: "instructor", else: "instructors"}"

          "#{first_three_names_str}, #{others_str}"
      end

    assigns = Map.put(assigns, :instructors, instructors)

    ~H"""
    {@instructors}
    """
  end
end
