defmodule OliWeb.Sections.SectionsTableModel do
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  use Surface.LiveComponent

  def new(%SessionContext{} = context, sections) do
    SortableTableModel.new(
      rows: sections,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &__MODULE__.custom_render/3
        },
        %ColumnSpec{
          name: :type,
          label: "Type",
          render_fn: &__MODULE__.custom_render/3,
          sort_fn: &__MODULE__.custom_sort/2
        },
        %ColumnSpec{
          name: :enrollments_count,
          label: "# Enrolled"
        },
        %ColumnSpec{
          name: :requires_payment,
          label: "Paid",
          render_fn: &__MODULE__.custom_render/3,
          sort_fn: &__MODULE__.custom_sort/2
        },
        %ColumnSpec{
          name: :start_date,
          label: "Start",
          render_fn: &OliWeb.Common.Table.Common.render_date/3,
          sort_fn: &OliWeb.Common.Table.Common.sort_date/2
        },
        %ColumnSpec{
          name: :end_date,
          label: "End",
          render_fn: &OliWeb.Common.Table.Common.render_date/3,
          sort_fn: &OliWeb.Common.Table.Common.sort_date/2
        },
        %ColumnSpec{
          name: :institution,
          label: "Institution",
          render_fn: &__MODULE__.custom_render/3,
          sort_fn: &__MODULE__.custom_sort/2
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context
      }
    )
  end

  def custom_sort(direction, %ColumnSpec{name: name}) do
    {fn r ->
       case name do
         :type ->
           if r.open_and_free do
             "Open"
           else
             "LMS"
           end

         :requires_payment ->
           if r.requires_payment do
             case Money.to_string(r.amount) do
               {:ok, m} -> m
               _ -> "Yes"
             end
           else
             "None"
           end

         :institution ->
           if is_nil(r.institution) do
             ""
           else
             r.institution.name
           end
       end
     end, direction}
  end

  def custom_render(assigns, section, %ColumnSpec{name: :title}) do
    ~F"""
    <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)}>{section.title}</a>
    """
  end

  def custom_render(_assigns, section, %ColumnSpec{name: :type}) do
    if section.open_and_free do
      "Open"
    else
      "LMS"
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

  def custom_render(_assigns, section, %ColumnSpec{name: :institution}) do
    if section.open_and_free do
      ""
    else
      section.institution.name
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
