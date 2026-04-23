defmodule Mix.Tasks.InstructorDashboard.Seed do
  @moduledoc """
  Seeds a local-only intelligent dashboard fixture for manual testing.

  The task creates a fresh project, publication, section, instructor, and learner set on each run,
  then populates progress, student-support, learning-objective, and assessment data so the full
  dashboard CSV export bundle is exercised.

  This task is not idempotent:
  - every run creates a new section and new users
  - the section slug and dashboard URL are not stable across runs
  - the created dashboard URL and credentials are printed after the task completes

  Options:
  - `--students`, `-s`: number of students to create; default `8`, minimum effective value `5`
  - `--password`, `-p`: password assigned to the created instructor and students;
    default `dashboard-pass-123`

  Examples:

      mix instructor_dashboard.seed
      mix instructor_dashboard.seed --students 12
      mix instructor_dashboard.seed --students 12 --password "dev-pass-456"
  """

  @shortdoc "Seed local dev data for interactive intelligent dashboard testing"

  use Mix.Task

  import Ecto.Query, only: [from: 2]

  alias Ecto.Changeset
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Analytics.Summary
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.ContainedObjective
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Seeder

  @default_password "dashboard-pass-123"
  @default_student_count 8

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    opts = parse_args(args)
    seed = seed_dashboard_fixture(opts)

    Mix.shell().info("""
    Seeded intelligent dashboard fixture.

    Section:
      title: #{seed.section.title}
      slug: #{seed.section.slug}
      dashboard: /sections/#{seed.section.slug}/instructor_dashboard/insights/dashboard

    Instructor:
      email: #{seed.instructor.email}
      password: #{seed.password}

    Students:
    #{Enum.map_join(seed.students, "\n", &"  - #{&1.email}")}

    Notes:
      - Multiple graded assessments, progress records, student-support summaries, and learning-objective proficiency rows are populated.
      - Re-run the task to create another independent fixture set.
    """)
  end

  defp parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [students: :integer, password: :string],
        aliases: [s: :students, p: :password]
      )

    %{
      students: max(Keyword.get(opts, :students, @default_student_count), 5),
      password: Keyword.get(opts, :password, @default_password)
    }
  end

  defp seed_dashboard_fixture(opts) do
    course = build_seed_course()
    section =
      Sections.update_section!(course.section_2, %{
        title: "Intelligent Dashboard Seed Section"
      })

    Sections.rebuild_contained_pages(section)
    Sections.rebuild_contained_objectives(section)

    timestamp = System.system_time(:second)
    email_prefix = "dashboard-seed-#{timestamp}"

    instructor =
      create_user(%{
        email: "#{email_prefix}-instructor@example.edu",
        password: opts.password,
        given_name: "Dashboard",
        family_name: "Instructor",
        can_create_sections: true
      })

    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

    students =
      1..opts.students
      |> Enum.map(fn index ->
        create_user(%{
          email: "#{email_prefix}-student#{index}@example.edu",
          password: opts.password,
          given_name: "Student",
          family_name: Integer.to_string(index)
        })
      end)

    Enum.each(students, fn student ->
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
    end)

    ensure_objective_section_resources(course, section)
    page_section_resources = configure_graded_pages(course, section)

    seed_page_activity(page_section_resources, section, students)
    seed_page_proficiency(page_section_resources, section, students)
    seed_objective_proficiency(course, section, students)
    ensure_objective_section_resources(course, section)

    %{
      section: section,
      instructor: instructor,
      students: students,
      password: opts.password
    }
  end

  defp create_user(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %User{}
    |> User.registration_changeset(attrs)
    |> Changeset.change(%{
      email_confirmed_at: now,
      age_verified: true,
      can_create_sections: Map.get(attrs, :can_create_sections, false)
    })
    |> Repo.insert!()
  end

  defp build_seed_course(attempt \\ 1)

  defp build_seed_course(attempt) when attempt <= 5 do
    Seeder.base_project_with_resource4()
  rescue
    error in MatchError ->
      if author_collision_error?(error) do
        build_seed_course(attempt + 1)
      else
        reraise error, __STACKTRACE__
      end
  end

  defp build_seed_course(_attempt) do
    raise "unable to build dashboard seed course after retrying around legacy author email collisions"
  end

  defp author_collision_error?(%MatchError{term: {:error, %Ecto.Changeset{} = changeset}}) do
    Enum.any?(changeset.errors, fn
      {:email, {"has already been taken", _details}} -> true
      _ -> false
    end)
  end

  defp author_collision_error?(_error), do: false

  defp configure_graded_pages(course, section) do
    assessment_revisions =
      [course.latest1, course.latest2, course.latest3]
      |> Enum.reject(&is_nil/1)
      |> Enum.with_index(1)
      |> Enum.map(fn {revision, index} ->
        revision
        |> Revision.changeset(%{
          graded: true,
          title: "Seeded Assessment #{index}"
        })
        |> Repo.update!()
      end)

    page_ids =
      Enum.map(assessment_revisions, & &1.resource_id)

    from(sr in SectionResource,
      where: sr.section_id == ^section.id and sr.resource_id in ^page_ids,
      order_by: [asc: sr.numbering_index]
    )
    |> Repo.all()
    |> Enum.with_index(1)
    |> Enum.map(fn {section_resource, index} ->
      {:ok, updated} =
        Sections.update_section_resource(section_resource, %{
          graded: true,
          title: "Seeded Assessment #{index}",
          start_date: DateTime.add(DateTime.utc_now(), -14 * 86_400, :second),
          end_date: DateTime.add(DateTime.utc_now(), index * 86_400, :second)
        })

      updated
    end)
  end

  defp seed_page_activity(page_section_resources, section, students) do
    [student_1, student_2, student_3, student_4, student_5, _student_6, student_7, student_8 | _] =
      students

    page_profiles = [
      %{student: student_1, progress: 0.0},
      %{student: student_2, progress: 0.2, score: 2.0, out_of: 10.0},
      %{student: student_3, progress: 0.55, score: 6.0, out_of: 10.0},
      %{student: student_4, progress: 1.0, score: 9.0, out_of: 10.0},
      %{student: student_5, progress: 1.0, score: 10.0, out_of: 10.0},
      %{student: student_7, progress: 0.1, score: 4.0, out_of: 10.0},
      %{student: student_8, progress: 1.0, score: 8.0, out_of: 10.0}
    ]

    Enum.with_index(page_section_resources)
    |> Enum.each(fn {page, index} ->
      Enum.each(page_profiles, fn profile ->
        attrs =
          profile
          |> Map.take([:progress, :score, :out_of])
          |> maybe_shift_assessment_score(index)

        seed_resource_access(page, section, profile.student, attrs)
      end)
    end)

    page_section_resources
  end

  defp seed_page_proficiency(page_section_resources, section, students) do
    page_type_id = ResourceType.id_for_page()
    [student_1, student_2, student_3, student_4, student_5, _student_6, student_7, student_8 | _] =
      students

    page_profiles = [
      {student_1, 2, 0},
      {student_2, 10, 2},
      {student_3, 10, 7},
      {student_4, 10, 9},
      {student_5, 10, 10},
      {student_7, 6, 2},
      {student_8, 10, 8}
    ]

    Enum.each(page_section_resources, fn page ->
      Enum.each(page_profiles, fn {student, attempts, correct} ->
        Summary.create_resource_summary(%{
          section_id: section.id,
          user_id: student.id,
          resource_id: page.resource_id,
          resource_type_id: page_type_id,
          num_first_attempts: attempts,
          num_first_attempts_correct: correct
        })
      end)
    end)

    :ok
  end

  defp seed_objective_proficiency(course, section, students) do
    objective_profiles = [
      {course.child1.resource.id, [{0, 0}, {10, 2}, {10, 2}, {10, 7}, {10, 9}, {10, 2}]},
      {course.child2.resource.id, [{10, 7}, {10, 8}, {10, 8}, {10, 9}, {10, 9}]},
      {course.child3.resource.id, [{10, 2}, {10, 3}, {10, 6}, {10, 5}, {10, 4}]},
      {course.child4.resource.id, [{10, 9}, {10, 10}, {10, 8}, {10, 9}, {10, 10}]},
      {course.child5.resource.id, [{10, 4}, {10, 3}, {10, 4}, {10, 5}, {10, 6}]},
      {course.parent1.resource.id, [{10, 2}, {10, 4}, {10, 5}, {10, 7}, {10, 8}]},
      {course.parent2.resource.id, [{10, 8}, {10, 8}, {10, 9}, {10, 9}, {10, 10}]},
      {course.parent3.resource.id, [{10, 3}, {10, 4}, {10, 4}, {10, 5}, {10, 6}]}
    ]

    objective_type_id = ResourceType.id_for_objective()

    objective_profiles
    |> Enum.each(fn {objective_id, profiles} ->
      profiles
      |> Enum.zip(students)
      |> Enum.each(fn {{attempts, correct}, student} ->
        {:ok, _summary} =
          Summary.create_resource_summary(%{
          section_id: section.id,
          user_id: student.id,
          resource_id: objective_id,
          resource_type_id: objective_type_id,
          num_first_attempts: attempts,
          num_first_attempts_correct: correct
        })
      end)
    end)

    :ok
  end

  defp ensure_objective_section_resources(course, section) do
    objective_entries = [
      {course.parent1, "Objective A", 200},
      {course.child1, "Objective A.1", 201},
      {course.child2, "Objective A.2", 202},
      {course.child3, "Objective A.3", 203},
      {course.parent2, "Objective B", 210},
      {course.child4, "Objective B.1", 211},
      {course.parent3, "Objective C", 220},
      {course.child5, "Objective C.1", 221}
    ]

    objective_entries
    |> Enum.each(fn {entry, title, numbering_index} ->
      ensure_objective_section_resource(entry, title, numbering_index, section, course.project.id)
      seed_contained_objective(section.id, nil, entry.resource.id)
      seed_contained_objective(section.id, course.container.resource.id, entry.resource.id)
    end)

    :ok
  end

  defp ensure_objective_section_resource(entry, title, numbering_index, section, project_id) do
    case Repo.get_by(SectionResource,
           section_id: section.id,
           resource_id: entry.resource.id
         ) do
      nil ->
        %SectionResource{}
        |> SectionResource.changeset(%{
          section_id: section.id,
          project_id: project_id,
          resource_id: entry.resource.id,
          revision_id: entry.revision.id,
          resource_type_id: ResourceType.id_for_objective(),
          title: title,
          slug: entry.revision.slug || "objective-#{entry.resource.id}",
          numbering_index: numbering_index,
          numbering_level: objective_numbering_level(entry.revision.children)
        })
        |> Repo.insert!()
        |> SectionResourceDepot.update_section_resource()

      %SectionResource{} = section_resource ->
        SectionResourceDepot.update_section_resource(section_resource)
    end
  end

  defp objective_numbering_level(children) when is_list(children) and children != [], do: 2
  defp objective_numbering_level(_children), do: 3

  defp seed_contained_objective(section_id, container_id, objective_id) do
    existing =
      case container_id do
        nil ->
          from(
            co in ContainedObjective,
            where:
              co.section_id == ^section_id and is_nil(co.container_id) and
                co.objective_id == ^objective_id
          )
          |> Repo.one()

        _ ->
          Repo.get_by(ContainedObjective,
            section_id: section_id,
            container_id: container_id,
            objective_id: objective_id
          )
      end

    case existing do
      nil ->
        %ContainedObjective{}
        |> ContainedObjective.changeset(%{
          section_id: section_id,
          container_id: container_id,
          objective_id: objective_id
        })
        |> Repo.insert!()

      _existing ->
        :ok
    end
  end

  defp seed_resource_access(section_resource, section, student, attrs) do
    section_resource.resource_id
    |> Core.track_access(section.id, student.id)
    |> Core.update_resource_access(attrs)
  end

  defp maybe_shift_assessment_score(%{score: score, out_of: out_of} = attrs, page_index)
       when is_number(score) and is_number(out_of) do
    adjusted_score =
      score
      |> Kernel.+(page_index)
      |> min(out_of)

    Map.put(attrs, :score, adjusted_score)
  end

  defp maybe_shift_assessment_score(attrs, _page_index), do: attrs
end
