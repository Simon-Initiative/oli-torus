defmodule OliWeb.Delivery.InstructorDashboard.Helpers do
  alias Oli.Delivery.{Metrics, Sections}
  alias Oli.Publishing.DeliveryResolver

  def get_containers(section) do
    case Sections.get_units_and_modules_containers(section.slug) do
      {0, pages} ->
        page_ids = Enum.map(pages, & &1.id)

        students =
          Sections.enrolled_students(section.slug)
          |> Enum.reject(fn user -> user.user_role_id != 4 end)

        student_progress =
          Metrics.progress_across_for_pages(
            section.id,
            page_ids,
            Enum.map(students, & &1.id)
          )

        proficiency_per_page = Metrics.proficiency_per_page(section.slug, page_ids)

        pages_with_metrics =
          Enum.map(pages, fn page ->
            Map.merge(page, %{
              progress: student_progress[page.id] || 0.0,
              student_proficiency: Map.get(proficiency_per_page, page.id, "Not enough data")
            })
          end)

        {0, pages_with_metrics}

      {total_count, containers} ->
        student_progress =
          Metrics.progress_across(
            section.id,
            Enum.map(containers, & &1.id),
            [],
            Sections.count_enrollments(section.slug)
          )

        proficiency_per_container = Metrics.proficiency_per_container(section.slug)

        containers_with_metrics =
          Enum.map(containers, fn container ->
            Map.merge(container, %{
              progress: student_progress[container.id] || 0.0,
              student_proficiency:
                Map.get(proficiency_per_container, container.id, "Not enough data")
            })
          end)

        {total_count, containers_with_metrics}
    end
  end

  def get_assessments(section, students) do
    student_ids = Enum.map(students, & &1.id)

    graded_pages_and_section_resources =
      DeliveryResolver.graded_pages_revisions_and_section_resources(section.slug)

    page_ids = Enum.map(graded_pages_and_section_resources, fn {rev, _} -> rev.resource_id end)

    progress_across_for_pages =
      Metrics.progress_across_for_pages(
        section.id,
        page_ids,
        student_ids
      )

    avg_score_across_for_pages =
      Metrics.avg_score_across_for_pages(
        section.id,
        page_ids,
        student_ids
      )

    attempts_across_for_pages =
      Metrics.attempts_across_for_pages(
        section.id,
        page_ids,
        student_ids
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

  def get_students(section, params \\ %{container_id: nil}) do
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
