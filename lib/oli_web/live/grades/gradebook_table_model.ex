defmodule OliWeb.Grades.GradebookTableModel do
  use Phoenix.Component

  alias Oli.Grading.GradebookRow
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Utils
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias OliWeb.Delivery.ScoreDisplay
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents

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
          label: "Student Name",
          render_fn: &__MODULE__.render_student/3,
          th_class: "pl-10 whitespace-nowrap !sticky left-0 z-10",
          td_class: "sticky left-0 z-10"
        }
      ] ++
        Enum.map(graded_pages, fn sr ->
          %ColumnSpec{
            name: sr.resource_id,
            label:
              if(sr.has_lti_activity,
                do: HTMLComponents.lti_label_component(%{title: sr.title, id: sr.resource_id}),
                else: sr.title
              ),
            render_fn: &__MODULE__.render_score/3,
            th_class: "whitespace-nowrap",
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

  def new_from_gradebook_rows(gradebook_rows, graded_pages, section, show_all_links) do
    rows =
      Enum.map(gradebook_rows, fn
        %GradebookRow{} = row ->
          score_map =
            Map.new(row.scores, fn score ->
              {score.resource_id,
               %ResourceAccess{
                 resource_id: score.resource_id,
                 user_id: row.user.id,
                 section_id: section.id,
                 score: score.score,
                 out_of: score.out_of,
                 was_late: score.was_late,
                 resource_attempts_count: Map.get(score, :resource_attempts_count)
               }}
            end)

          Map.merge(score_map, %{user: row.user, id: row.user.id, section: section})

        %{user: user, scores: scores} ->
          score_map =
            Map.new(scores, fn score ->
              {score.resource_id,
               %ResourceAccess{
                 resource_id: score.resource_id,
                 user_id: user.id,
                 section_id: section.id,
                 score: score.score,
                 out_of: score.out_of,
                 was_late: score.was_late,
                 resource_attempts_count: Map.get(score, :resource_attempts_count)
               }}
            end)

          Map.merge(score_map, %{user: user, id: user.id, section: section})
      end)

    column_specs =
      [
        %ColumnSpec{
          name: :name,
          label: "Student Name",
          render_fn: &__MODULE__.render_student/3,
          th_class: "pl-10 whitespace-nowrap !sticky left-0 z-10",
          td_class: "sticky left-0 z-10"
        }
      ] ++
        Enum.map(graded_pages, fn sr ->
          %ColumnSpec{
            name: sr.resource_id,
            label:
              if(sr.has_lti_activity,
                do: HTMLComponents.lti_label_component(%{title: sr.title, id: sr.resource_id}),
                else: sr.title
              ),
            render_fn: &__MODULE__.render_score/3,
            th_class: "whitespace-nowrap",
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
        label: "Assessment",
        render_fn: &__MODULE__.render_grade/3,
        th_class: "pl-10"
      },
      %ColumnSpec{
        name: :score,
        label: "Score",
        render_fn: &__MODULE__.render_grade_score/3,
        th_class: "pl-10",
        sortable: false
      }
    ]

    SortableTableModel.new(
      rows: graded_pages,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id],
      data: %{section_slug: section_slug, student_id: student_id}
    )
  end

  def render_grade_order(assigns, row, _) do
    assigns = Map.merge(assigns, %{row: row})

    ~H"""
    <div class="ml-8">
      {@row.index}
    </div>
    """
  end

  def render_grade(assigns, row, _) do
    assigns = Map.merge(assigns, %{row: row})

    ~H"""
    <div>
      {@row.label}
    </div>
    """
  end

  def render_grade_score(assigns, row, _) do
    perc = score(row.score) / out_of_score(row.out_of) * 100
    score_status = ScoreDisplay.score_status(row.score, row.out_of)
    has_score? = row.score != nil
    was_late = row.was_late
    score = if has_score?, do: Utils.format_score(row.score)
    out_of = Utils.format_score(row.out_of)

    assigns =
      Map.merge(assigns, %{
        perc: perc,
        score_status: score_status,
        has_score?: has_score?,
        was_late: was_late,
        row: row,
        score: score,
        out_of: out_of
      })

    ~H"""
    <div>
      <a
        class={grade_score_link_class(@score_status, @has_score?)}
        href={
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Progress.StudentResourceView,
            @section_slug,
            @student_id,
            @row.resource_id
          )
        }
      >
        <%= if @has_score? do %>
          {"#{@score}/#{@out_of}"}
        <% else %>
          Not Finished
        <% end %>
      </a>
      <%= if @was_late do %>
        <span class="ml-2 inline-flex items-center justify-center px-2 py-1 rounded-[999px] bg-Icon-icon-danger text-white text-xs font-semibold shadow-[0px_2px_4px_0px_rgba(0,52,99,0.1)]">
          LATE
        </span>
      <% end %>
    </div>
    """
  end

  def render_student(assigns, row, _) do
    disapproved_count =
      Map.values(row)
      |> Enum.count(fn elem ->
        is_resource_access?(elem) and has_score?(elem) and
          ScoreDisplay.score_status(elem.score, elem.out_of) == :bad
      end)

    assigns = Map.merge(assigns, %{disapproved_count: disapproved_count, row: row})

    ~H"""
    <div class="text-Text-text-high">
      {OliWeb.Common.Utils.name(@row.user)}
    </div>
    """
  end

  defp is_resource_access?(%Oli.Delivery.Attempts.Core.ResourceAccess{}), do: true
  defp is_resource_access?(_), do: false

  defp has_score?(%Oli.Delivery.Attempts.Core.ResourceAccess{score: nil}), do: false
  defp has_score?(%Oli.Delivery.Attempts.Core.ResourceAccess{}), do: true

  defp out_of_score(number) when number in [nil, 0, +0.0, -0.0], do: 1
  defp out_of_score(number), do: number

  defp score(nil), do: 0
  defp score(number), do: number

  def render_score(assigns, row, %ColumnSpec{name: resource_id}) do
    assigns = Map.merge(assigns, %{row: row, resource_id: resource_id})

    case Map.get(row, resource_id) do
      # Indicates that this student has never visited this resource and has no attempt
      nil ->
        show_no_attempt(assigns)

      # Indicates that this student has visited, but never started an assessment attempt
      %ResourceAccess{score: nil, out_of: nil, resource_attempts_count: 0} ->
        show_no_attempt(assigns)

      # Indicates that this student has started, but not completed this assessment
      %ResourceAccess{score: nil, out_of: nil} ->
        case assigns.show_all_links do
          true ->
            ~H"""
            <a href={
              Routes.live_path(
                OliWeb.Endpoint,
                OliWeb.Progress.StudentResourceView,
                @row.section.slug,
                @row.id,
                @resource_id
              )
            }>
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

  defp show_no_attempt(assigns) do
    case assigns.show_all_links do
      true ->
        ~H"""
        <a href={
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Progress.StudentResourceView,
            @row.section.slug,
            @row.id,
            @resource_id
          )
        }>
          <span class="text-muted">No Attempt</span>
        </a>
        """

      _ ->
        ""
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
    assigns =
      Map.merge(assigns, %{
        row: row,
        resource_id: resource_id,
        score: score,
        out_of: out_of,
        was_late: was_late
      })

    if out_of == 0 or out_of == 0.0 do
      ~H"""
      <a href={
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Progress.StudentResourceView,
          @row.section.slug,
          @row.id,
          @resource_id
        )
      }>
        <.score_badge score={@score} out_of={@out_of} />
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
      score_status = ScoreDisplay.score_status(score, out_of)

      assigns =
        Map.merge(assigns, %{
          perc: perc,
          safe_out_of: safe_out_of,
          safe_score: safe_score,
          score_status: score_status
        })

      ~H"""
      <a href={
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Progress.StudentResourceView,
          @row.section.slug,
          @row.id,
          @resource_id
        )
      }>
        <.score_badge score={@safe_score} out_of={@safe_out_of} score_status={@score_status} />
      </a>
      <%= if @was_late do %>
        <span class="ml-2 w-11 h-5 inline-flex items-center justify-center px-2 py-1 rounded-[999px] bg-Icon-icon-danger text-white text-xs shadow-[0px_2px_4px_0px_rgba(0,52,99,0.1)]">
          LATE
        </span>
      <% end %>
      """
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  attr :score, :any, required: true
  attr :out_of, :any, required: true
  attr :score_status, :atom, default: :none

  defp score_badge(assigns) do
    ~H"""
    <%= if @score_status == :bad do %>
      <span class="text-Text-text-danger no-underline">{@score}</span><span class="text-Text-text-high">{"/#{@out_of}"}</span>
    <% else %>
      <span class="text-Text-text-button no-underline">{@score}</span><span class="text-Text-text-high">{"/#{@out_of}"}</span>
    <% end %>
    """
  end

  defp grade_score_link_class(:bad, true), do: "text-red-500"
  defp grade_score_link_class(_score_status, true), do: "text-black dark:text-gray-300"
  defp grade_score_link_class(_score_status, false), do: "text-black dark:text-gray-300"
end
