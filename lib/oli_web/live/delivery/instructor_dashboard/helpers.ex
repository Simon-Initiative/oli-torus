defmodule OliWeb.Delivery.InstructorDashboard.Helpers do
  alias Oli.Delivery.{Metrics, Sections}
  alias Oli.Publishing.DeliveryResolver

  def get_containers(section) do
    {total_count, containers} = Sections.get_units_and_modules_containers(section.slug)

    student_progress =
      get_students_progress(
        total_count,
        containers,
        section.id,
        Sections.count_enrollments(section.slug)
      )

    proficiency_per_container = Metrics.proficiency_per_container(section.slug)

    # when those metrics are ready (see Oli.Delivery.Metrics)

    containers_with_metrics =
      Enum.map(containers, fn container ->
        Map.merge(container, %{
          progress: student_progress[container.id] || 0.0,
          student_proficiency: Map.get(proficiency_per_container, container.id, "Not enough data")
        })
      end)

    {total_count, containers_with_metrics}
  end

  def get_assessments(section, students) do
    graded_pages_and_section_resources =
      DeliveryResolver.graded_pages_revisions_and_section_resources(section.slug)

    page_ids = Enum.map(graded_pages_and_section_resources, fn {rev, _} -> rev.resource_id end)

    progress_across_for_pages =
      Metrics.progress_across_for_pages(
        section.id,
        page_ids,
        [],
        Enum.count(students)
      )

    avg_score_across_for_pages =
      Metrics.avg_score_across_for_pages(
        section.id,
        page_ids,
        []
      )

    attempts_across_for_pages =
      Metrics.attempts_across_for_pages(
        section.id,
        page_ids
      )

    container_labels = Sections.map_resources_with_container_labels(section.slug, page_ids)

    graded_pages_and_section_resources
    |> Enum.map(fn {rev, sr} ->
      Map.merge(rev, %{
        end_date: sr.end_date,
        students_completion: Map.get(progress_across_for_pages, rev.resource_id),
        scheduling_type: sr.scheduling_type,
        container_label: Map.get(container_labels, rev.resource_id),
        avg_score: Map.get(avg_score_across_for_pages, rev.resource_id),
        total_attempts: Map.get(attempts_across_for_pages, rev.resource_id)
      })
    end)
  end

  defp get_students_progress(0, pages, section_id, students_count) do
    page_ids = Enum.map(pages, fn p -> p.id end)

    Metrics.progress_across_for_pages(
      section_id,
      page_ids,
      [],
      students_count
    )
  end

  defp get_students_progress(_total_count, containers, section_id, students_count) do
    container_ids = Enum.map(containers, fn c -> c.id end)

    Metrics.progress_across(
      section_id,
      container_ids,
      [],
      students_count
    )
  end

  def get_students(section, params \\ %{container_id: nil}) do
    # when that metric is ready (see Oli.Delivery.Metrics)
    case params[:page_id] do
      nil ->
        Sections.enrolled_students(section.slug)
        |> add_students_progress(section.id, params.container_id)
        |> add_students_last_interaction(section, params.container_id)
        |> add_students_overall_proficiency(section, params.container_id)

      page_id ->
        Sections.enrolled_students(section.slug)
        |> add_students_progress_for_page(section.id, page_id)
        |> add_students_last_interaction_for_page(section.slug, page_id)
        |> add_students_overall_proficiency_for_page(section.slug, page_id)
    end
  end

  defp add_students_progress(students, section_id, container_id) do
    students_progress =
      Metrics.progress_for(section_id, Enum.map(students, & &1.id), container_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{progress: Map.get(students_progress, student.id)})
    end)
  end

  defp add_students_progress_for_page(students, section_id, page_id) do
    students_progress =
      Metrics.progress_for_page(section_id, Enum.map(students, & &1.id), page_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{progress: Map.get(students_progress, student.id)})
    end)
  end

  defp add_students_last_interaction(students, section, container_id) do
    students_last_interaction = Metrics.students_last_interaction_across(section, container_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{last_interaction: Map.get(students_last_interaction, student.id)})
    end)
  end

  defp add_students_last_interaction_for_page(students, section_slug, page_id) do
    students_last_interaction = Metrics.students_last_interaction_for_page(section_slug, page_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{last_interaction: Map.get(students_last_interaction, student.id)})
    end)
  end

  defp add_students_overall_proficiency(students, section, container_id) do
    proficiency_per_student = Metrics.proficiency_per_student_across(section, container_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{
        overall_proficiency: Map.get(proficiency_per_student, student.id, "Not enough data")
      })
    end)
  end

  defp add_students_overall_proficiency_for_page(students, section_slug, page_id) do
    proficiency_per_student_for_page =
      Metrics.proficiency_per_student_for_page(section_slug, page_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{
        overall_proficiency:
          Map.get(proficiency_per_student_for_page, student.id, "Not enough data")
      })
    end)
  end
end
