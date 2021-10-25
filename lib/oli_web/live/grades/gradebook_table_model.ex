defmodule OliWeb.Grades.GradebookTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Surface.LiveComponent
  alias Oli.Delivery.Attempts.Core.ResourceAccess

  def new(enrollments, graded_pages, resource_accesses) do
    by_user =
      Enum.reduce(resource_accesses, %{}, fn ra, m ->
        case Map.has_key?(m, ra.user_id) do
          true ->
            user = Map.get(m, ra.user_id)
            Map.put(m, ra.user_id, Map.put(user, ra.resource_id, ra))

          false ->
            Map.put(m, ra.user_id, Map.put(%{}, ra.resource_id, ra))
        end
      end)

    rows =
      Enum.map(enrollments, fn user ->
        Map.get(by_user, user.id, %{})
        |> Map.merge(%{user: user, id: user.id})
      end)

    column_specs =
      [
        %ColumnSpec{
          name: :student,
          label: "Student",
          render_fn: &__MODULE__.render_student/3
        }
      ] ++
        Enum.map(graded_pages, fn revision ->
          %ColumnSpec{
            name: revision.resource_id,
            label: revision.title,
            render_fn: &__MODULE__.render_score/3
          }
        end)

    SortableTableModel.new(
      rows: rows,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_student(_, row, _) do
    OliWeb.Common.Utils.name(row.user)
  end

  def render_score(_, row, %ColumnSpec{name: resource_id}) do
    case Map.get(row, resource_id) do
      nil -> ""
      %ResourceAccess{score: nil, out_of: nil} -> ""
      %ResourceAccess{score: score, out_of: out_of} -> calculate_score(score, out_of)
    end
  end

  defp calculate_score(score, out_of) do
    case out_of do
      0 ->
        "0%"

      _ ->
        ((score / out_of)
         |> Float.round(2)
         |> Float.to_string()) <> "%"
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
