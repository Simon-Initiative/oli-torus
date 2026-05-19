defmodule Oli.InstructorDashboard.Oracles.ConcreteOraclesTest do
  use Oli.DataCase

  import Ecto.Query
  import Oli.Factory

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Oracles.Grades
  alias Oli.InstructorDashboard.Oracles.ObjectivesProficiency
  alias Oli.InstructorDashboard.Oracles.ProgressBins
  alias Oli.InstructorDashboard.Oracles.ProgressProficiency
  alias Oli.InstructorDashboard.Oracles.SchedulePosition
  alias Oli.InstructorDashboard.Oracles.ScopeResources
  alias Oli.InstructorDashboard.Oracles.StudentInfo
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @grades_execute_event [:oli, :dashboard, :oracle, :execute]

  setup do
    map =
      Seeder.base_project_with_larger_hierarchy()
      |> Seeder.add_users_to_section(:section, [:student_a, :student_b])
      |> Seeder.add_user(
        %{email: "instructor.oracles@example.edu", given_name: "Inst", family_name: "Ructor"},
        :instructor
      )

    map =
      Seeder.add_enrollment(
        map,
        map.instructor.id,
        map.section.id,
        :instructor_enrollment,
        :context_instructor
      )

    {:ok, _} = Sections.rebuild_contained_pages(map.section)

    {:ok, map: map}
  end

  describe "ProgressBins oracle" do
    test "returns fixed 0..100 bins per container and includes missing learners as 0%", %{
      map: map
    } do
      [page_1, page_2, _page_3] = map.mod1_pages

      set_progress(map.section.id, page_1.resource.id, map.student_a.id, 1.0)
      set_progress(map.section.id, page_2.resource.id, map.student_a.id, 0.5)

      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.unit1_resource.id}
        )

      assert {:ok, payload} =
               ProgressBins.load(context, axis_container_ids: [map.mod1_resource.id])

      assert payload.bin_size == 10
      assert payload.total_students == 2

      container_bins = payload.by_container_bins[map.mod1_resource.id]

      assert container_bins[50] == 1
      assert container_bins[0] == 1
      assert Map.keys(container_bins) |> Enum.sort() == Enum.to_list(0..100//10)
    end

    test "returns by_resource_bins for mixed direct children without breaking by_container_bins",
         %{
           map: map
         } do
      direct_page = add_direct_page_child(map, map.unit1_resource.id, "Unit 1 extra page")
      [page_1, _page_2, _page_3] = map.mod1_pages

      set_progress(map.section.id, page_1.resource.id, map.student_a.id, 1.0)
      set_progress(map.section.id, direct_page.resource_id, map.student_a.id, 1.0)

      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.unit1_resource.id}
        )

      assert {:ok, payload} = ProgressBins.load(context, [])

      assert payload.total_students == 2
      assert Map.has_key?(payload.by_container_bins, map.mod1_resource.id)
      assert Map.has_key?(payload.by_resource_bins, map.mod1_resource.id)
      assert Map.has_key?(payload.by_resource_bins, direct_page.resource_id)

      module_bins = payload.by_resource_bins[map.mod1_resource.id]
      direct_page_bins = payload.by_resource_bins[direct_page.resource_id]

      assert module_bins[40] == 1
      assert module_bins[0] == 1
      assert direct_page_bins[100] == 1
      assert direct_page_bins[0] == 1
    end
  end

  describe "SchedulePosition oracle" do
    test "returns the current unit for course scope based on scheduled descendants", %{map: map} do
      [mod1_page_1 | _] = map.mod1_pages
      [mod2_page_1 | _] = map.mod2_pages
      [mod3_page_1 | _] = map.mod3_pages
      now = ~U[2026-02-18 12:00:00Z]

      schedule_resource(
        map.section.id,
        mod1_page_1.resource.id,
        ~U[2026-02-09 00:00:00Z],
        ~U[2026-02-15 23:59:59Z]
      )

      schedule_resource(
        map.section.id,
        mod2_page_1.resource.id,
        ~U[2026-02-16 00:00:00Z],
        ~U[2026-02-22 23:59:59Z]
      )

      schedule_resource(
        map.section.id,
        mod3_page_1.resource.id,
        ~U[2026-03-02 00:00:00Z],
        ~U[2026-03-08 23:59:59Z]
      )

      context = build_context(map.section.id, map.instructor.id, %{container_type: :course})

      assert {:ok, payload} = SchedulePosition.load(context, now: now)
      assert payload.has_schedule? == true
      assert payload.current_resource_id == map.unit1_resource.id
      assert payload.label == "Schedule: Unit 1"
    end

    test "returns the current direct child for unit scope", %{map: map} do
      [mod1_page_1 | _] = map.mod1_pages
      [mod2_page_1 | _] = map.mod2_pages
      now = ~U[2026-02-18 12:00:00Z]

      schedule_resource(
        map.section.id,
        mod1_page_1.resource.id,
        ~U[2026-02-09 00:00:00Z],
        ~U[2026-02-15 23:59:59Z]
      )

      schedule_resource(
        map.section.id,
        mod2_page_1.resource.id,
        ~U[2026-02-16 00:00:00Z],
        ~U[2026-02-22 23:59:59Z]
      )

      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.unit1_resource.id}
        )

      assert {:ok, payload} = SchedulePosition.load(context, now: now)
      assert payload.current_resource_id == map.mod2_resource.id
      assert payload.label == "Schedule: Module 2"
    end

    test "returns the next scheduled page closest to today for module scope", %{map: map} do
      [page_1, page_2, page_3] = map.mod2_pages
      now = ~U[2026-02-18 12:00:00Z]

      schedule_resource(
        map.section.id,
        page_1.resource.id,
        ~U[2026-02-16 00:00:00Z],
        ~U[2026-02-16 23:59:59Z]
      )

      schedule_resource(
        map.section.id,
        page_2.resource.id,
        ~U[2026-02-20 00:00:00Z],
        ~U[2026-02-20 23:59:59Z]
      )

      schedule_resource(
        map.section.id,
        page_3.resource.id,
        ~U[2026-02-24 00:00:00Z],
        ~U[2026-02-24 23:59:59Z]
      )

      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.mod2_resource.id}
        )

      assert {:ok, payload} = SchedulePosition.load(context, now: now)
      assert payload.current_resource_id == page_2.resource.id
      assert payload.label == "Schedule: Page 2"
    end

    test "returns has_schedule false when the section has no scheduled resources", %{map: map} do
      context = build_context(map.section.id, map.instructor.id, %{container_type: :course})

      assert {:ok, %{has_schedule?: false}} =
               SchedulePosition.load(context, now: ~U[2026-02-18 12:00:00Z])
    end

    test "does not project a schedule marker into scopes that do not contain the global position",
         %{
           map: map
         } do
      direct_course_page =
        add_direct_page_child(map, map.container.resource.id, "Acknowledgements")

      [unit1_page_1 | _] = map.mod1_pages
      now = ~U[2026-03-27 12:00:00Z]

      schedule_resource(
        map.section.id,
        unit1_page_1.resource.id,
        ~U[2026-02-09 00:00:00Z],
        ~U[2026-02-15 23:59:59Z]
      )

      schedule_resource(
        map.section.id,
        direct_course_page.resource_id,
        ~U[2026-02-20 00:00:00Z],
        ~U[2026-02-20 23:59:59Z]
      )

      course_context =
        build_context(map.section.id, map.instructor.id, %{container_type: :course})

      assert {:ok, course_payload} = SchedulePosition.load(course_context, now: now)
      assert course_payload.current_resource_id == direct_course_page.resource_id

      unit_context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.unit1_resource.id}
        )

      assert {:ok, unit_payload} = SchedulePosition.load(unit_context, now: now)
      assert unit_payload.has_schedule? == true
      refute Map.has_key?(unit_payload, :current_resource_id)
    end
  end

  describe "ProgressProficiency oracle" do
    test "returns one row per learner with progress defaulting to 0 and proficiency threshold gating",
         %{map: map} do
      [page_1, page_2, _page_3] = map.mod1_pages
      page_type_id = ResourceType.id_for_page()

      set_progress(map.section.id, page_1.resource.id, map.student_a.id, 1.0)
      set_progress(map.section.id, page_2.resource.id, map.student_a.id, 0.5)

      insert(:resource_summary, %{
        section_id: map.section.id,
        project_id: -1,
        user_id: map.student_a.id,
        resource_id: page_1.resource.id,
        resource_type_id: page_type_id,
        num_first_attempts: 5,
        num_first_attempts_correct: 4
      })

      insert(:resource_summary, %{
        section_id: map.section.id,
        project_id: -1,
        user_id: map.student_b.id,
        resource_id: page_1.resource.id,
        resource_type_id: page_type_id,
        num_first_attempts: 2,
        num_first_attempts_correct: 2
      })

      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.mod1_resource.id}
        )

      assert {:ok, rows} = ProgressProficiency.load(context, [])
      assert Enum.count(rows) == 2

      row_a = Enum.find(rows, &(&1.student_id == map.student_a.id))
      row_b = Enum.find(rows, &(&1.student_id == map.student_b.id))

      assert_in_delta row_a.progress_pct, 50.0, 0.0001
      assert_in_delta row_a.proficiency_pct, 0.84, 0.0001
      assert row_b.progress_pct == 0.0
      assert row_b.proficiency_pct == nil
    end
  end

  describe "StudentInfo oracle" do
    test "returns learner identity fields plus enrollment-sourced last_interaction_at", %{
      map: map
    } do
      expected_last_interaction_at = ~U[2026-02-01 10:00:00Z]

      from(e in Enrollment, where: e.id == ^map.student_a_enrollment.id)
      |> Repo.update_all(set: [updated_at: expected_last_interaction_at])

      context = build_context(map.section.id, map.instructor.id, %{container_type: :course})

      assert {:ok, rows} = StudentInfo.load(context, [])
      assert Enum.count(rows) == 2

      student_a_row = Enum.find(rows, &(&1.student_id == map.student_a.id))

      assert student_a_row.email == map.student_a.email
      assert student_a_row.last_interaction_at == expected_last_interaction_at
      refute Enum.any?(rows, &(&1.student_id == map.instructor.id))
    end
  end

  describe "ScopeResources oracle" do
    test "returns scoped descendant items with relative context labels", %{map: map} do
      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.unit1_resource.id}
        )

      assert {:ok, payload} = ScopeResources.load(context, [])
      assert payload.course_title == map.section.title
      assert payload.scope_label == "Unit 1"

      resource_ids = payload.items |> Enum.map(& &1.resource_id) |> Enum.sort()

      assert Enum.sort([map.mod1_resource.id, map.mod2_resource.id]) -- resource_ids == []

      page_item =
        Enum.find(payload.items, &(&1.resource_id == hd(map.mod1_pages).resource.id))

      assert page_item.context_label == "Module 1"
    end

    test "returns course-scoped descendant items with full ancestor chains", %{map: map} do
      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :course}
        )

      assert {:ok, payload} = ScopeResources.load(context, [])

      page_item =
        Enum.find(payload.items, &(&1.resource_id == hd(map.mod1_pages).resource.id))

      assert page_item.context_label == "Unit 1 > Module 1"
    end
  end

  describe "Grades oracle" do
    test "returns per-page aggregate stats, histograms, schedule metadata, and not-completed helper",
         %{map: map} do
      [page_1, page_2, _page_3] = map.mod1_pages

      available_at = ~U[2026-03-01 14:00:00Z]
      due_at = ~U[2026-03-07 23:59:59Z]

      mark_page_graded(map.section.id, page_1.resource.id, available_at, due_at)
      mark_page_graded(map.section.id, page_2.resource.id, nil, nil)

      assert Repo.aggregate(
               from(sr in SectionResource,
                 where:
                   sr.section_id == ^map.section.id and sr.graded == true and
                     sr.resource_id in ^[page_1.resource.id, page_2.resource.id]
               ),
               :count
             ) == 2

      assert Repo.aggregate(
               from(cp in Oli.Delivery.Sections.ContainedPage,
                 where:
                   cp.section_id == ^map.section.id and cp.container_id == ^map.mod1_resource.id and
                     cp.page_id in ^[page_1.resource.id, page_2.resource.id]
               ),
               :count
             ) >= 2

      set_grade(map.section.id, page_1.resource.id, map.student_a.id, 8.0, 10.0)
      set_grade(map.section.id, page_1.resource.id, map.student_b.id, 5.0, 10.0)
      set_grade(map.section.id, page_2.resource.id, map.student_b.id, 10.0, 10.0)

      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.mod1_resource.id}
        )

      assert {:ok, payload} = Grades.load(context, [])
      assert Enum.count(payload.grades) == 2

      page_1_row = Enum.find(payload.grades, &(&1.page_id == page_1.resource.id))
      page_2_row = Enum.find(payload.grades, &(&1.page_id == page_2.resource.id))

      assert_in_delta page_1_row.minimum, 50.0, 0.0001
      assert_in_delta page_1_row.maximum, 80.0, 0.0001
      assert_in_delta page_1_row.mean, 65.0, 0.0001
      assert_in_delta page_1_row.median, 65.0, 0.0001
      assert_in_delta page_1_row.standard_deviation, 15.0, 0.0001
      assert page_1_row.histogram["50-60"] == 1
      assert page_1_row.histogram["80-90"] == 1
      assert page_1_row.available_at == available_at
      assert page_1_row.due_at == due_at

      assert_in_delta page_2_row.minimum, 100.0, 0.0001
      assert_in_delta page_2_row.mean, 100.0, 0.0001
      assert page_2_row.histogram["90-100"] == 1

      assert {:ok, students} =
               Grades.students_without_attempt_emails(map.section.id, page_2.resource.id)

      assert [
               %{id: student_id, email: student_email, display_name: display_name}
             ] = students

      assert student_id == map.student_a.id
      assert student_email == map.student_a.email
      assert is_binary(display_name)
    end

    test "students_without_attempt_emails includes learners who started but did not complete", %{
      map: map
    } do
      [page_1, _page_2, _page_3] = map.mod1_pages

      mark_page_graded(map.section.id, page_1.resource.id, nil, nil)
      set_grade(map.section.id, page_1.resource.id, map.student_a.id, 8.0, 10.0)
      set_started_access(map.section.id, page_1.resource.id, map.student_b.id)

      assert {:ok, students} =
               Grades.students_without_attempt_emails(map.section.id, page_1.resource.id)

      assert [
               %{id: student_id, email: student_email, display_name: display_name}
             ] = students

      assert student_id == map.student_b.id
      assert student_email == map.student_b.email
      assert is_binary(display_name)
    end

    test "students_without_attempt_emails returns empty list when all enrolled learners attempted",
         %{
           map: map
         } do
      [page_1, _page_2, _page_3] = map.mod1_pages

      mark_page_graded(map.section.id, page_1.resource.id, nil, nil)
      set_grade(map.section.id, page_1.resource.id, map.student_a.id, 8.0, 10.0)
      set_grade(map.section.id, page_1.resource.id, map.student_b.id, 9.0, 10.0)

      assert {:ok, students} =
               Grades.students_without_attempt_emails(map.section.id, page_1.resource.id)

      assert students == []
    end

    test "emits telemetry with latency and row counts for load and no-attempt helper", %{map: map} do
      [page_1, _page_2, _page_3] = map.mod1_pages
      mark_page_graded(map.section.id, page_1.resource.id, nil, nil)
      set_grade(map.section.id, page_1.resource.id, map.student_a.id, 8.0, 10.0)

      handler = attach_telemetry([@grades_execute_event])

      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.mod1_resource.id}
        )

      assert {:ok, _payload} = Grades.load(context, [])

      assert {:ok, _students} =
               Grades.students_without_attempt_emails(map.section.id, page_1.resource.id)

      assert_receive {:telemetry_event, @grades_execute_event, load_measurements,
                      %{action: :load} = load_metadata}

      assert load_metadata.oracle_key == :oracle_instructor_grades
      assert load_metadata.outcome == :ok
      assert load_metadata.section_id == map.section.id
      assert load_metadata.container_id == map.mod1_resource.id
      assert is_integer(load_measurements.duration_ms)
      assert is_integer(load_measurements.row_count)
      assert is_integer(load_measurements.payload_size)

      assert_receive {:telemetry_event, @grades_execute_event, helper_measurements,
                      %{action: :students_without_attempt_emails} = helper_metadata}

      assert helper_metadata.oracle_key == :oracle_instructor_grades
      assert helper_metadata.outcome == :ok
      assert helper_metadata.section_id == map.section.id
      assert helper_metadata.container_id == nil
      assert is_integer(helper_measurements.duration_ms)
      assert is_integer(helper_measurements.row_count)
      assert is_integer(helper_measurements.payload_size)

      :telemetry.detach(handler)
    end
  end

  describe "ObjectivesProficiency oracle" do
    test "returns scope-contained objective proficiency distributions using objective_id payloads",
         %{map: map} do
      objective_type_id = ResourceType.id_for_objective()

      objective_1 = insert(:resource)
      objective_2 = insert(:resource)

      sr1 =
        insert(:section_resource, %{
          section: map.section,
          project: map.project,
          resource_id: objective_1.id,
          resource_type_id: objective_type_id,
          title: "Objective A",
          slug: "objective-a-#{objective_1.id}"
        })

      sr2 =
        insert(:section_resource, %{
          section: map.section,
          project: map.project,
          resource_id: objective_2.id,
          resource_type_id: objective_type_id,
          title: "Objective B",
          slug: "objective-b-#{objective_2.id}"
        })

      SectionResourceDepot.update_section_resource(sr1)
      SectionResourceDepot.update_section_resource(sr2)

      insert(:contained_objective, %{
        section: map.section,
        container_id: map.mod1_resource.id,
        objective_id: objective_1.id
      })

      insert(:contained_objective, %{
        section: map.section,
        container_id: map.mod1_resource.id,
        objective_id: objective_2.id
      })

      insert(:resource_summary, %{
        section_id: map.section.id,
        project_id: -1,
        user_id: map.student_a.id,
        resource_id: objective_1.id,
        resource_type_id: objective_type_id,
        num_first_attempts: 5,
        num_first_attempts_correct: 4
      })

      insert(:resource_summary, %{
        section_id: map.section.id,
        project_id: -1,
        user_id: map.student_a.id,
        resource_id: objective_2.id,
        resource_type_id: objective_type_id,
        num_first_attempts: 5,
        num_first_attempts_correct: 1
      })

      insert(:resource_summary, %{
        section_id: map.section.id,
        project_id: -1,
        user_id: map.student_b.id,
        resource_id: objective_2.id,
        resource_type_id: objective_type_id,
        num_first_attempts: 5,
        num_first_attempts_correct: 5
      })

      context =
        build_context(
          map.section.id,
          map.instructor.id,
          %{container_type: :container, container_id: map.mod1_resource.id}
        )

      assert {:ok, payload} = ObjectivesProficiency.load(context, [])
      rows = payload.objective_rows

      assert Enum.count(rows) == 2
      assert Enum.any?(payload.objective_resources, &(&1.resource_id == objective_1.id))
      assert Enum.any?(payload.objective_resources, &(&1.resource_id == objective_2.id))

      objective_1_row = Enum.find(rows, &(&1.objective_id == objective_1.id))
      objective_2_row = Enum.find(rows, &(&1.objective_id == objective_2.id))

      assert objective_1_row.title == "Objective A"
      assert objective_1_row.proficiency_distribution["High"] == 1
      assert objective_1_row.proficiency_distribution["Not enough data"] == 1

      assert objective_2_row.title == "Objective B"
      assert objective_2_row.proficiency_distribution["Low"] == 1
      assert objective_2_row.proficiency_distribution["High"] == 1
    end
  end

  defp build_context(section_id, user_id, scope) do
    {:ok, context} =
      OracleContext.new(%{
        dashboard_context_type: :section,
        dashboard_context_id: section_id,
        user_id: user_id,
        scope: scope
      })

    context
  end

  defp set_progress(section_id, page_id, user_id, progress) do
    %ResourceAccess{
      access_count: 1,
      section_id: section_id,
      resource_id: page_id,
      user_id: user_id,
      progress: progress
    }
    |> Repo.insert!()
  end

  defp set_grade(section_id, page_id, user_id, score, out_of) do
    %ResourceAccess{
      access_count: 1,
      section_id: section_id,
      resource_id: page_id,
      user_id: user_id,
      score: score,
      out_of: out_of
    }
    |> Repo.insert!()
  end

  defp set_started_access(section_id, page_id, user_id) do
    %ResourceAccess{
      access_count: 1,
      section_id: section_id,
      resource_id: page_id,
      user_id: user_id,
      progress: 0.1
    }
    |> Repo.insert!()
  end

  defp mark_page_graded(section_id, resource_id, available_at, due_at) do
    page_type_id = ResourceType.id_for_page()

    from(sr in SectionResource,
      where: sr.section_id == ^section_id and sr.resource_id == ^resource_id
    )
    |> Repo.update_all(
      set: [
        graded: true,
        resource_type_id: page_type_id,
        start_date: available_at,
        end_date: due_at
      ]
    )

    section_resource =
      Repo.get_by!(SectionResource, section_id: section_id, resource_id: resource_id)

    SectionResourceDepot.update_section_resource(section_resource)
  end

  defp attach_telemetry(events) do
    handler_id = "concrete-oracles-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _config ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end

  defp add_direct_page_child(map, parent_resource_id, title) do
    page_type_id = ResourceType.id_for_page()

    revision =
      insert(:revision, %{
        resource_type_id: page_type_id,
        title: title,
        graded: false,
        content: %{"advancedDelivery" => true}
      })

    section_resource =
      insert(:section_resource, %{
        section: map.section,
        project: map.project,
        resource_id: revision.resource_id,
        revision_id: revision.id,
        resource_type_id: page_type_id,
        title: title,
        slug: "progress-direct-page-#{revision.resource_id}"
      })

    parent_section_resource =
      Repo.get_by!(SectionResource, section_id: map.section.id, resource_id: parent_resource_id)

    {:ok, _updated_parent} =
      Sections.update_section_resource(parent_section_resource, %{
        children: parent_section_resource.children ++ [section_resource.id]
      })

    SectionResourceDepot.update_section_resource(section_resource)
    {:ok, _} = Sections.rebuild_contained_pages(map.section)

    section_resource
  end

  defp schedule_resource(section_id, resource_id, start_date, end_date) do
    from(sr in SectionResource,
      where: sr.section_id == ^section_id and sr.resource_id == ^resource_id
    )
    |> Repo.update_all(
      set: [
        start_date: start_date,
        end_date: end_date,
        removed_from_schedule: false,
        hidden: false
      ]
    )

    section_resource =
      Repo.get_by!(SectionResource, section_id: section_id, resource_id: resource_id)

    SectionResourceDepot.update_section_resource(section_resource)
  end
end
