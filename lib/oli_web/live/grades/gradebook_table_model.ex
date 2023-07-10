defmodule OliWeb.Grades.GradebookTableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Utils
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Tag

  def new(enrollments, graded_pages, resource_accesses, section, show_all_links) do
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
        |> Map.merge(%{user: user, id: user.id, section: section})
      end)

    column_specs =
      [
        %ColumnSpec{
          name: :name,
          label: "STUDENT NAME",
          render_fn: &__MODULE__.render_student/3,
          th_class: "pl-10 instructor_dashboard_th"
        }
      ] ++
        Enum.map(graded_pages, fn revision ->
          %ColumnSpec{
            name: revision.resource_id,
            label: String.upcase(revision.title),
            render_fn: &__MODULE__.render_score/3,
            th_class: "instructor_dashboard_th",
            sortable: false
          }
        end)

    SortableTableModel.new(
      rows: rows,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{show_all_links: show_all_links}
    )
  end

  def new(graded_pages, section_slug, student_id) do
    column_specs = [
      %ColumnSpec{
        name: :name,
        label: "Quiz",
        render_fn: &__MODULE__.render_grade/3,
        th_class: "pl-10 instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :score,
        label: "Score",
        render_fn: &__MODULE__.render_grade_score/3,
        th_class: "pl-10 instructor_dashboard_th",
        sortable: false
      }
    ]

    SortableTableModel.new(
      rows: graded_pages,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{section_slug: section_slug, student_id: student_id}
    )
  end

  def render_grade(assigns, row, _) do
    ~F"""
      <div class="ml-8">
        {row.label}
      </div>
    """
  end

  def render_grade_score(assigns, row, _) do
    perc = score(row.score) / out_of_score(row.out_of) * 100
    has_score? = row.score != nil
    was_late = row.was_late
    ~F"""
      <a
        class={"ml-8 #{if has_score? and perc < 40, do: "text-red-500", else: "text-black"}"}
        data-score-check={if has_score? and perc < 40, do: "false", else: "true"}
        href={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentResourceView, assigns.section_slug, assigns.student_id, row.resource_id)}
      >
        {#if has_score?}
          {row.score}/{row.out_of}
        {#else}
          Not Finished
        {/if}
      </a>
      {#if was_late}
        <Tag.render>LATE</Tag.render>
      {/if}
    """
  end

  def render_student(assigns, row, _) do
    disapproved_count =
      Map.values(row)
      |> Enum.count(fn elem ->
        is_resource_access?(elem) and has_score?(elem) and
          score(elem.score) / out_of_score(elem.out_of) * 100 < 40
      end)

    ~F"""
      <div class="ml-8" data-score-check={if disapproved_count > 0, do: "false", else: "true"}>
        {OliWeb.Common.Utils.name(row.user)}
      </div>
    """
  end

  defp is_resource_access?(%Oli.Delivery.Attempts.Core.ResourceAccess{}), do: true
  defp is_resource_access?(_), do: false

  defp has_score?(%Oli.Delivery.Attempts.Core.ResourceAccess{score: nil}), do: false
  defp has_score?(%Oli.Delivery.Attempts.Core.ResourceAccess{}), do: true

  defp out_of_score(nil), do: 1
  defp out_of_score(0), do: 1
  defp out_of_score(0.0), do: 1
  defp out_of_score(number), do: number

  defp score(nil), do: 0
  defp score(number), do: number

  def render_score(assigns, row, %ColumnSpec{name: resource_id}) do
    case Map.get(row, resource_id) do
      # Indicates that this student has never visited this resource
      nil ->
        case assigns.show_all_links do
          true ->
            ~F"""
            <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentResourceView, row.section.slug, row.id, resource_id)}>
              <span class="text-muted">Never Visited</span>
            </a>
            """

          _ ->
            ""
        end

      # Indicates that this student has visited, but not completed this assessment
      %ResourceAccess{score: nil, out_of: nil} ->
        case assigns.show_all_links do
          true ->
            ~F"""
            <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentResourceView, row.section.slug, row.id, resource_id)}>
              <span>Not Finished</span>
            </a>
            """

          _ ->
            ""
        end

      # We have a rolled-up grade from at least one attempt
      %ResourceAccess{} = resource_access ->
        show_score(assigns, row, resource_id, resource_access)
    end
  end

  defp show_score(
         assigns,
         row,
         resource_id,
         %ResourceAccess{
           score: score,
           out_of: out_of,
           was_late: was_late
         }
       ) do
    if out_of == 0 or out_of == 0.0 do
      ~F"""
      <a class="text-red-500" href={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentResourceView, row.section.slug, row.id, resource_id)}>
        <span>{score}/{out_of}</span>
      </a>
      """
    else
      safe_score =
        if is_nil(score) do
          "?"
        else
          Utils.format_score(score)
        end

      safe_out_of =
        if is_nil(out_of) do
          "?"
        else
          out_of
        end

      perc = safe_score / safe_out_of * 100

      ~F"""
        <a class={if perc < 50, do: "text-red-500", else: "text-black"} href={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentResourceView, row.section.slug, row.id, resource_id)}>
        {safe_score}/{safe_out_of}
        </a>
        {#if was_late}
          <Tag.render>LATE</Tag.render>
        {/if}
      """
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
