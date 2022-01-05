defmodule OliWeb.Grades.UpdatesTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Surface.LiveComponent
  alias Oli.Delivery.Attempts.Core.ResourceAccess

  alias OliWeb.Router.Helpers, as: Routes

  def new(page_nodes, resource_accesses, section, user, local_tz) do
    rows =
      Enum.with_index(page_nodes, fn node, index ->
        ra = Map.get(resource_accesses, node.revision.resource_id)

        %{
          resource_id: node.revision.resource_id,
          node: node,
          index: index,
          title: node.revision.title,
          type:
            if node.revision.graded do
              "Graded"
            else
              "Practice"
            end,
          score:
            if is_nil(ra) do
              nil
            else
              ra.score
            end,
          out_of:
            if is_nil(ra) do
              nil
            else
              ra.out_of
            end,
          number_attempts:
            if is_nil(ra) do
              0
            else
              ra.resource_attempts_count
            end,
          number_accesses:
            if is_nil(ra) do
              0
            else
              ra.access_count
            end,
          updated_at:
            if is_nil(ra) do
              nil
            else
              ra.updated_at
            end,
          inserted_at:
            if is_nil(ra) do
              nil
            else
              ra.inserted_at
            end
        }
      end)

    {:ok, model} =
      SortableTableModel.new(
        rows: rows,
        column_specs: [
          %ColumnSpec{
            name: :index,
            label: "Order"
          },
          %ColumnSpec{
            name: :title,
            label: "Resource Title",
            render_fn: &__MODULE__.custom_render/3
          },
          %ColumnSpec{
            name: :type,
            label: "Type"
          },
          %ColumnSpec{
            name: :score,
            label: "Score",
            render_fn: &__MODULE__.custom_render/3,
            sort_fn: &__MODULE__.custom_sort/2
          },
          %ColumnSpec{
            name: :number_attempts,
            label: "# Attempts",
            render_fn: &__MODULE__.custom_render/3
          },
          %ColumnSpec{
            name: :number_accesses,
            label: "# Accesses",
            render_fn: &__MODULE__.custom_render/3
          },
          %ColumnSpec{
            name: :updated_at,
            label: "First Visited",
            render_fn: &__MODULE__.custom_render/3,
            sort_fn: &OliWeb.Common.Table.Common.render_date/3
          },
          %ColumnSpec{
            name: :updated_at,
            label: "Last Visited",
            render_fn: &__MODULE__.custom_render/3,
            sort_fn: &OliWeb.Common.Table.Common.render_date/3
          }
        ],
        event_suffix: "",
        id_field: [:index],
        data: %{
          local_tz: local_tz
        }
      )

    {:ok, Map.put(model, :data, %{section_slug: section.slug, user_id: user.id})}
  end

  def custom_sort(direction, %ColumnSpec{name: name}) do
    {fn r ->
       case name do
         :score ->
           if r.type == "Graded" and !is_nil(r.score) and r.out_of != 0 do
             r.score / r.out_of
           else
             0.0
           end
       end
     end, direction}
  end

  def custom_render(assigns, row, %ColumnSpec{name: name}) do
    case name do
      :title ->
        ~F"""
        <ResourceTitle
          node={row.node}
          url={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentResourceView, assigns.section_slug, assigns.user_id, row.resource_id)}/>
        """

      :score ->
        if row.type == "Graded" and !is_nil(row.score) do
          "#{row.score} / #{row.out_of}"
        else
          ""
        end

      :number_accesses ->
        if row.number_accesses == 0 do
          ""
        else
          row.number_accesses
        end

      :number_attempts ->
        if row.number_attempts == 0 do
          ""
        else
          row.number_attempts
        end

      _ ->
        case Map.get(row, name) do
          nil -> ""
          d -> Timex.format!(d, "%Y-%m-%d", :strftime)
        end
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
