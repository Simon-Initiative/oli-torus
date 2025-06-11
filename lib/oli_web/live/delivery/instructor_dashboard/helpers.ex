defmodule OliWeb.Delivery.InstructorDashboard.Helpers do
  alias Oli.Delivery.{Certificates, GrantedCertificates, Metrics, Sections}
  alias Oli.Publishing.DeliveryResolver

  def get_containers(section, opts \\ [async: true]) do
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

        proficiency_per_page = Metrics.proficiency_per_page(section, page_ids)

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

        proficiency_per_container =
          if opts[:async] do
            %{}
          else
            contained_pages = Oli.Delivery.Sections.get_contained_pages(section)
            Metrics.proficiency_per_container(section, contained_pages)
          end

        containers_with_metrics =
          Enum.map(containers, fn container ->
            Map.merge(container, %{
              progress: student_progress[container.id] || 0.0,
              student_proficiency: Map.get(proficiency_per_container, container.id, "Loading...")
            })
          end)

        {total_count, containers_with_metrics}
    end
  end

  def get_assessments(section, students) do
    Oli.Delivery.Sections.SectionResourceDepot.graded_pages(section.id)
    |> return_page(section, students)
  end

  def maybe_assign_certificate_data(
        %{assigns: %{section: %{certificate_enabled: false}}} = socket
      ),
      do:
        Phoenix.Component.assign(
          socket,
          %{
            certificate: nil,
            certificate_pending_email_notification_count: nil
          }
        )

  def maybe_assign_certificate_data(socket) do
    section = socket.assigns.section

    certificate = Certificates.get_certificate_by(%{section_id: section.id})

    certificate_pending_email_notification_count =
      GrantedCertificates.certificate_pending_email_notification_count(section.slug)

    Phoenix.Component.assign(
      socket,
      %{
        certificate: certificate,
        certificate_pending_email_notification_count: certificate_pending_email_notification_count
      }
    )
  end

  def certificate_pending_approval_count(
        students,
        %{requires_instructor_approval: true} = _certificate
      ) do
    Enum.reduce(students, 0, fn student, acc ->
      if student.certificate && student.certificate.state == :pending do
        acc + 1
      else
        acc
      end
    end)
  end

  def certificate_pending_approval_count(_students, _certificate), do: nil

  defp return_page(graded_pages_and_section_resources, section, _students) do
    # Create a map of all section resource ids to their parent container labels
    container_labels =
      Oli.Delivery.Sections.SectionResourceDepot.containers(section.id)
      |> Enum.reduce(%{}, fn container, acc ->
        Enum.reduce(container.children, acc, fn sr_id, acc ->
          label =
            Sections.get_container_label_and_numbering(
              container.numbering_level,
              container.numbering_index,
              section.customizations
            )

          Map.put(acc, sr_id, {container.resource_id, "#{label}: #{container.title}"})
        end)
      end)

    graded_pages_and_section_resources
    |> Enum.with_index(1)
    |> Enum.map(fn {r, index} ->
      {container_id, label} = Map.get(container_labels, r.id, {nil, nil})

      Map.merge(r, %{
        container_id: container_id,
        order: index,
        end_date: r.end_date,
        students_completion: nil,
        scheduling_type: r.scheduling_type,
        container_label: label,
        avg_score: nil,
        total_attempts: nil
      })
    end)
  end

  def load_metrics(resources, section, students) do
    student_ids = Enum.map(students, & &1.id)
    page_ids = Enum.map(resources, fn r -> r.resource_id end)

    progress_across_for_pages =
      Metrics.progress_across_for_pages(section.id, page_ids, student_ids)

    avg_score_across_for_pages =
      Metrics.avg_score_across_for_pages(section, page_ids, student_ids)

    attempts_across_for_pages =
      Metrics.attempts_across_for_pages(section, page_ids, student_ids, false)

    resources
    |> Enum.map(fn r ->
      Map.merge(r, %{
        students_completion: Map.get(progress_across_for_pages, r.resource_id),
        avg_score: Map.get(avg_score_across_for_pages, r.resource_id),
        total_attempts: Map.get(attempts_across_for_pages, r.resource_id)
      })
    end)
  end

  def get_practice_pages(section, students) do
    Oli.Delivery.Sections.SectionResourceDepot.practice_pages(section.id)
    |> return_page(section, students)
  end

  def get_assessments_with_surveys(section, students) do
    page_ids = DeliveryResolver.pages_with_surveys(section.slug)

    Oli.Delivery.Sections.SectionResourceDepot.get_pages(section.id, page_ids)
    |> return_page(section, students)
  end

  @valid_contexts ~w(context_administrator context_content_developer context_instructor context_learner context_mentor context_manager context_member context_officer)a
  def get_students(section, context_role)
      when is_atom(context_role) and context_role in @valid_contexts do
    get_students(section, [context_role])
  end

  def get_students(section, context_roles) when is_list(context_roles) do
    get_students(section, %{container_id: nil}, context_roles)
  end

  def get_students(section, params \\ %{container_id: nil}, context_roles \\ @valid_contexts) do
    case params[:page_id] do
      nil ->
        Sections.enrolled_students(section.slug, context_roles)
        |> add_students_progress(section.id, params.container_id)
        |> add_students_last_interaction(section, params.container_id)
        |> add_students_overall_proficiency(section, params.container_id)
        |> maybe_add_certificates(section)

      page_id ->
        Sections.enrolled_students(section.slug, context_roles)
        |> add_students_progress_for_page(section.id, page_id)
        |> add_students_last_interaction_for_page(section.slug, page_id)
        |> add_students_overall_proficiency_for_page(section, page_id)
        |> maybe_add_certificates(section)
    end
  end

  @doc """
  Builds a list of units and modules for a given section id, used as options to filter pages by container.
  The containers are sorted as they appear in the curriculum.
  Example:
  [
    %{
      id: 140217,
      title: "Introduction",
      resource_id: 10462,
      numbering_index: 1,
      numbering_level: 1
    },
    %{
      id: 140216,
      title: "Enum",
      resource_id: 10465,
      numbering_index: 1,
      numbering_level: 2
    },
    %{
      id: 140215,
      title: "Basics",
      resource_id: 10464,
      numbering_index: 2,
      numbering_level: 2
    },
    %{
      id: 140218,
      title: "Building a Phoenix App",
      resource_id: 10463,
      numbering_index: 2,
      numbering_level: 1
    }
  ]
  """
  def build_units_and_modules_options(section_id) do
    units =
      Oli.Delivery.Sections.SectionResourceDepot.containers(section_id,
        numbering_level: {:in, [1]}
      )
      |> Enum.map(fn sr ->
        Map.take(sr, [:resource_id, :numbering_level, :numbering_index, :title, :id, :children])
      end)
      |> Enum.sort_by(& &1.numbering_index)

    modules_mapper =
      Oli.Delivery.Sections.SectionResourceDepot.containers(section_id,
        numbering_level: {:in, [2]}
      )
      |> Enum.map(fn sr ->
        Map.take(sr, [:resource_id, :numbering_level, :numbering_index, :title, :id])
      end)
      |> Enum.into(%{}, fn module -> {module.id, module} end)

    sort_containers(units, modules_mapper)
  end

  defp sort_containers(units, modules_mapper) do
    # Sorts container units and modules as they appear in the curriculum
    # Example:
    # Given the following curriculum structure:
    # - Unit 1
    #   - Module 1
    #   - Module 2
    # - Unit 2
    #   - Module 3
    #   - Module 4

    # Will be sorted as:
    # [Unit_1_data, Module_1_data, Module_2_data, Unit_2_data, Module_3_data, Module_4_data]

    Enum.reduce(units, [], fn unit, acum ->
      modules_contained_by_unit =
        Map.get(unit, :children, [])
        |> Enum.map(fn child_id -> Map.get(modules_mapper, child_id) end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.numbering_index, :desc)

      unit_with_contained_modules = [modules_contained_by_unit | [Map.drop(unit, [:children])]]

      [unit_with_contained_modules | acum]
    end)
    |> List.flatten()
    |> Enum.reverse()
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

  defp add_students_overall_proficiency_for_page(students, section, page_id) do
    proficiency_per_student_for_page = Metrics.proficiency_per_student_for_page(section, page_id)

    Enum.map(students, fn student ->
      Map.merge(student, %{
        overall_proficiency:
          Map.get(proficiency_per_student_for_page, student.id, "Not enough data")
      })
    end)
  end

  defp maybe_add_certificates(students, %{certificate_enabled: false}), do: students

  defp maybe_add_certificates(students, section) do
    certificates =
      Certificates.get_granted_certificates_by_section_id(section.id)
      |> Enum.into(%{}, fn cert -> {cert.recipient.id, cert} end)

    Enum.map(students, fn student ->
      Map.put(student, :certificate, Map.get(certificates, student.id))
    end)
  end
end
