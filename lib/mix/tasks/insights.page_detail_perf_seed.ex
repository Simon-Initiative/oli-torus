defmodule Mix.Tasks.Insights.PageDetailPerfSeed do
  @moduledoc """
  Seeds a disposable, high-cardinality Insights page-detail fixture.

  The course, publication, section, embedded activity, and instructor enrollment are
  created through `Oli.Scenarios`, the same application paths used by integration
  scenarios. The task then adds only the volume needed for the query benchmark.
  """

  use Mix.Task

  import Ecto.Query

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Analytics.Summary
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @database "oli_ng_insights_perf"
  @scenario_path "priv/scenarios/insights_page_detail_perf.scenario.yaml"
  @instructor_email "insights-perf-instructor@example.edu"
  @password "insights-perf-5838"
  @student_count 500
  @attempted_student_count 350
  @default_noise_project_scopes 100

  @shortdoc "Seed a disposable, high-cardinality Insights page-detail fixture"

  @impl Mix.Task
  def run([]) do
    ensure_dedicated_database!()
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    ensure_scenario_is_valid!()
    %{section: section, scored_page: scored_page, practice_page: practice_page, activity: activity} =
      create_real_delivery_fixture!()

    noise_project_scopes = noise_project_scopes!()
    student_ids = create_and_enroll_students(section)
    seed_page_summaries(section, scored_page.resource_id, student_ids, true, noise_project_scopes)

    seed_page_summaries(
      section,
      practice_page.resource_id,
      student_ids,
      false,
      noise_project_scopes
    )

    seed_activity_summaries(section, scored_page.resource_id, activity.resource_id, student_ids)

    verify_fixture!(section, scored_page, practice_page, activity)
    print_access_details(section, scored_page, practice_page, noise_project_scopes)
  end

  defp ensure_dedicated_database! do
    case System.get_env("DB_NAME") do
      @database -> :ok
      other -> Mix.raise("Refusing to seed: DB_NAME must be #{@database}, got #{inspect(other)}")
    end
  end

  defp ensure_scenario_is_valid! do
    case Scenarios.validate_file(@scenario_path) do
      :ok -> :ok
      {:error, errors} -> Mix.raise("scenario is invalid: #{inspect(errors)}")
    end
  end

  defp create_real_delivery_fixture! do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    if result.errors != [] do
      Mix.raise("scenario fixture failed: #{inspect(result.errors)}")
    end

    section = result.state.sections["insights_perf_section"]
    project = result.state.projects["insights_perf_course"]
    activity = result.state.activity_virtual_ids[{"insights_perf_course", "performance_question_1"}]

    section = Repo.update!(Ecto.Changeset.change(section, analytics_version: :v2))
    scored_page = project.rev_by_title["Scored page with attempts"]
    practice_page = project.rev_by_title["Practice page without attempts"]

    %{section: section, scored_page: scored_page, practice_page: practice_page, activity: activity}
  end

  defp create_and_enroll_students(section) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    password_hash = Bcrypt.hash_pwd_salt(@password)

    students =
      for index <- 1..@student_count do
        %{
          email: "insights-perf-student-#{index}@example.edu",
          password_hash: password_hash,
          sub: "insights-perf-student-#{index}",
          given_name: "Student",
          family_name: Integer.to_string(index),
          email_verified: true,
          email_confirmed_at: now,
          age_verified: true,
          guest: false,
          independent_learner: false,
          can_create_sections: false,
          research_opt_out: false,
          inserted_at: now,
          updated_at: now
        }
      end

    {_count, rows} = Repo.insert_all(User, students, returning: [:id])
    student_ids = Enum.map(rows, & &1.id)
    {:ok, _} = Sections.enroll(student_ids, section.id, [ContextRoles.get_role(:context_learner)])
    student_ids
  end

  defp noise_project_scopes! do
    case System.get_env("NOISE_PROJECT_SCOPES", Integer.to_string(@default_noise_project_scopes)) do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {count, ""} when count >= 0 -> count
          _ -> Mix.raise("NOISE_PROJECT_SCOPES must be a non-negative integer, got #{inspect(value)}")
        end
    end
  end

  defp seed_page_summaries(section, page_id, student_ids, include_attempts?, noise_project_scopes) do
    page_type_id = ResourceType.id_for_page()
    attempted_ids = if include_attempts?, do: Enum.take(student_ids, @attempted_student_count), else: []

    delivery_rows =
      Enum.map(attempted_ids, &summary_row(-1, section.id, &1, page_id, page_type_id, nil))

    insert_in_batches("resource_summary", delivery_rows)

    insert_noise_summaries(section.id, page_id, page_type_id, noise_project_scopes)
  end

  defp seed_activity_summaries(section, page_id, activity_id, student_ids) do
    {:ok, response} =
      Summary.create_resource_part_response(%{
        resource_id: activity_id,
        part_id: "1",
        response: "correct",
        label: "Correct"
      })

    {:ok, _} =
      Summary.create_response_summary(%{
        project_id: -1,
        section_id: section.id,
        page_id: page_id,
        activity_id: activity_id,
        resource_part_response_id: response.id,
        part_id: "1",
        count: @attempted_student_count
      })

    activity_type_id = ResourceType.id_for_activity()

    Repo.insert_all("resource_summary", [
      summary_row(-1, section.id, -1, activity_id, activity_type_id, "1")
    ])

    insert_in_batches(
      "student_responses",
      Enum.map(Enum.take(student_ids, @attempted_student_count), fn student_id ->
        %{section_id: section.id, page_id: page_id, resource_part_response_id: response.id, user_id: student_id}
      end)
    )
  end

  defp summary_row(project_id, section_id, user_id, resource_id, resource_type_id, part_id) do
    %{
      project_id: project_id,
      section_id: section_id,
      user_id: user_id,
      resource_id: resource_id,
      resource_type_id: resource_type_id,
      part_id: part_id,
      num_correct: 300,
      num_attempts: @attempted_student_count,
      num_hints: 0,
      num_first_attempts: @attempted_student_count,
      num_first_attempts_correct: 300
    }
  end

  defp insert_in_batches(table, rows), do: rows |> Enum.chunk_every(5_000) |> Enum.each(&Repo.insert_all(table, &1))

  defp insert_noise_summaries(_section_id, _page_id, _page_type_id, 0), do: :ok

  defp insert_noise_summaries(section_id, page_id, page_type_id, noise_project_scopes) do
    Repo.query!(
      """
      INSERT INTO resource_summary (
        project_id, section_id, user_id, resource_id, resource_type_id, part_id,
        num_correct, num_attempts, num_hints, num_first_attempts, num_first_attempts_correct
      )
      SELECT scopes.project_id, $1, students.id, $2, $3, NULL,
             300, $4, 0, $4, 300
      FROM generate_series(1, $5) AS scopes(project_id)
      CROSS JOIN (
        SELECT id
        FROM users
        WHERE email LIKE 'insights-perf-student-%@example.edu'
      ) AS students
      """,
      [section_id, page_id, page_type_id, @attempted_student_count, noise_project_scopes]
    )
  end

  defp verify_fixture!(section, scored_page, practice_page, activity) do
    {scored_revisions, _} = Enum.unzip(DeliveryResolver.graded_pages_revisions_and_section_resources(section.slug))
    {practice_revisions, _} = Enum.unzip(DeliveryResolver.ungraded_pages_revisions_and_section_resources(section.slug))

    unless Enum.any?(scored_revisions, &(&1.resource_id == scored_page.resource_id)) and
             Enum.any?(practice_revisions, &(&1.resource_id == practice_page.resource_id)) do
      Mix.raise("fixture pages are not visible in their expected Insights tabs")
    end

    visible_activities =
      from(rs in Oli.Analytics.Summary.ResponseSummary,
        where: rs.section_id == ^section.id and rs.page_id == ^scored_page.resource_id and rs.project_id == -1,
        select: rs.activity_id
      )
      |> Repo.all()

    resolved_activities = DeliveryResolver.from_resource_id(section.slug, visible_activities)

    unless Enum.any?(resolved_activities, &(&1.resource_id == activity.resource_id)) do
      Mix.raise("fixture activity is not resolvable from the delivery section")
    end

    instructor = Repo.get_by!(User, email: @instructor_email)

    unless instructor.can_create_sections and Sections.is_instructor?(instructor, section.slug) do
      Mix.raise("fixture instructor cannot access the Instructor Workspace")
    end
  end

  defp print_access_details(section, scored_page, practice_page, noise_project_scopes) do
    Mix.shell().info("""

    MER-5838 Insights performance fixture seeded in #{@database}.

    Instructor login
      email: #{@instructor_email}
      password: #{@password}

    URLs
      scored, with attempts: /sections/#{section.slug}/instructor_dashboard/insights/scored_pages/#{scored_page.resource_id}
      practice, no attempts: /sections/#{section.slug}/instructor_dashboard/insights/practice_pages/#{practice_page.resource_id}

    Dataset: #{@student_count} enrolled students, #{@attempted_student_count} with delivery-scope attempts,
    one real embedded activity, and #{noise_project_scopes} unrelated project scopes per student.
    Expected resource_summary rows: #{2 * noise_project_scopes * @student_count + @attempted_student_count + 1}.
    """)
  end
end
