defmodule OliWeb.Attempt.TableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Icons

  def new(members) do
    SortableTableModel.new(
      rows: members,
      column_specs: [
        %ColumnSpec{
          name: :chevron,
          label: "",
          sortable: false,
          render_fn: &__MODULE__.render_chevron/3
        },
        %ColumnSpec{
          name: :updated,
          label: "Updated",
          render_fn: &__MODULE__.render_updated/3
        },
        %ColumnSpec{
          name: :attempt_guid,
          label: "Attempt Guid"
        },
        %ColumnSpec{
          name: :resource_id,
          label: "Resource Id"
        },
        %ColumnSpec{
          name: :attempt_number,
          label: "Attempt Number"
        },
        %ColumnSpec{
          name: :activity_title,
          label: "Title"
        },
        %ColumnSpec{
          name: :lifecycle_state,
          label: "State"
        },
        %ColumnSpec{
          name: :score,
          label: "Score"
        },
        %ColumnSpec{
          name: :out_of,
          label: "Out Of"
        },
        %ColumnSpec{
          name: :scoreable,
          label: "Scoreable"
        },
        %ColumnSpec{
          name: :date_evaluated,
          label: "Date Evaluated",
          sort_fn: &Common.sort_date/2
        }
      ],
      event_suffix: "",
      # Must match the chevron's phx-value-id and the expanded_rows MapSet keys
      # — aligning all three lets row-click and chevron-click hit the same entry.
      id_field: [:unique_id]
    )
  end

  def render_updated(assigns, row, _) do
    if row.updated do
      ~H"""
      <div style="background-color: black; color: white;">UPDATED</div>
      """
    else
      ~H"""
      <div></div>
      """
    end
  end

  def render_chevron(assigns, row, _) do
    expanded_rows = assigns.model.data[:expanded_rows] || MapSet.new()
    row_id = "row_#{row.id}"
    is_expanded = MapSet.member?(expanded_rows, row_id)

    # Fresh assigns map (not Map.merge on incoming) preserves aria-expanded change tracking.
    assigns = %{id: row_id, row: row, is_expanded: is_expanded}

    ~H"""
    <button
      type="button"
      id={"button_#{@id}"}
      class="-m-1 flex items-center justify-center rounded border-0 bg-transparent p-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Border-border-focus"
      aria-expanded={@is_expanded}
      aria-controls={"details-#{@id}"}
      aria-label={"Toggle details for attempt #{@row.attempt_number}"}
      phx-click="toggle_row"
      phx-value-id={@id}
    >
      <%= if @is_expanded do %>
        <Icons.chevron_up class="fill-Text-text-high" />
      <% else %>
        <Icons.chevron_down class="fill-Text-text-high" />
      <% end %>
    </button>
    """
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
