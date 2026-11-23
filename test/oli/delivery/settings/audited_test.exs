defmodule Oli.Delivery.Settings.AuditedTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Auditing.{Changes, Context}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Settings.Audited
  alias Oli.Delivery.Settings.{AssessmentSettings, StudentException}
  alias Oli.Utils.Seeder

  setup do
    author = insert(:author)

    seeds =
      Seeder.Project.create_sample_project(%{}, author,
        project_tag: :project,
        publication_tag: :publication
      )

    Seeder.Project.ensure_published(seeds, seeds.publication)
    publication = Oli.Publishing.get_latest_published_publication_by_slug(seeds.project.slug)

    {:ok, section} =
      SectionsAudited.create_section_from_publication(
        audit_context(),
        publication,
        %{
          title: "Settings",
          type: :enrollable,
          base_project_id: seeds.project.id,
          context_id: UUID.uuid4()
        },
        rebuild: true
      )

    [assessment] = AssessmentSettings.get_assessments(section, [])
    instructor = insert(:user)

    {:ok, _} =
      Sections.enroll(instructor.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

    %{
      section: section,
      resource_id: assessment.resource_id,
      instructor: instructor,
      context: Context.for_actor(instructor, source: :ui)
    }
  end

  describe "assessment settings" do
    test "a new start date that moves the end date is recorded in one event", %{
      section: section,
      resource_id: resource_id,
      context: context,
      instructor: instructor
    } do
      # After the due date, so the due date moves to keep the distance
      start = ~U[2030-02-01 10:00:00Z]

      {:ok, _} =
        Audited.update_assessment_settings(context, section, resource_id, %{
          start_date: ~U[2030-01-01 10:00:00Z],
          end_date: ~U[2030-01-08 10:00:00Z]
        })

      assert {:ok, %{applied_changes: applied}} =
               Audited.update_assessment_settings(context, section, resource_id, %{
                 start_date: start
               })

      assert Map.has_key?(applied, :end_date)

      [_first, moved] = audit_events(:assessment_settings_changed, resource_id: resource_id)

      assert moved.changes["start_date"]["after"] == DateTime.to_iso8601(start)
      assert Map.has_key?(moved.changes, "end_date")
      assert {moved.user_id, moved.entity_type} == {instructor.id, :resource}
    end

    test "a change to the current value records nothing", %{
      section: section,
      resource_id: resource_id,
      context: context
    } do
      current = Sections.get_section_resource(section.id, resource_id).max_attempts

      assert {:ok, _} =
               Audited.update_assessment_settings(context, section, resource_id, %{
                 max_attempts: current
               })

      assert audit_events(:assessment_settings_changed, resource_id: resource_id) == []
    end

    test "a page that is not an assessment of the section is not found", %{
      section: section,
      context: context
    } do
      assert {:error, {:assessment_not_found, 0}} =
               Audited.update_assessment_settings(context, section, 0, %{max_attempts: 2})
    end

    test "an assessment change inside another transaction is refused", %{
      section: section,
      resource_id: resource_id,
      context: context
    } do
      assert {:ok, {:error, :nested_transaction}} =
               Repo.transaction(fn ->
                 Audited.update_assessment_settings(context, section, resource_id, %{
                   max_attempts: 7
                 })
               end)
    end

    test "the generic section resource writer refuses assessment settings", %{
      section: section,
      resource_id: resource_id
    } do
      section_resource = Sections.get_section_resource(section.id, resource_id)

      for attrs <- [%{max_attempts: 9}, %{"password" => "x"}, %{end_date: DateTime.utc_now()}] do
        assert {:error, :protected} = Sections.update_section_resource(section_resource, attrs)
      end
    end

    test "nothing is written when the event cannot be recorded", %{
      section: section,
      resource_id: resource_id,
      context: context
    } do
      before = Repo.get_by!(SectionResource, section_id: section.id, resource_id: resource_id)
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn ->
                 Audited.update_assessment_settings(context, section, resource_id, %{
                   max_attempts: (before.max_attempts || 0) + 5
                 })
               end)

      assert Repo.get!(SectionResource, before.id).max_attempts == before.max_attempts
    end
  end

  describe "bulk apply" do
    setup do
      author = insert(:author)
      project = insert(:project, authors: [author])

      pages =
        for n <- 1..3 do
          insert(:revision,
            resource_type_id: Oli.Resources.ResourceType.id_for_page(),
            title: "Quiz #{n}",
            graded: true
          )
        end

      root =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "Root",
          children: Enum.map(pages, & &1.resource_id)
        )

      publication = insert(:publication, project: project, root_resource_id: root.resource_id)

      for revision <- [root | pages] do
        insert(:published_resource,
          publication: publication,
          resource: revision.resource,
          revision: revision,
          author: author
        )
      end

      section = insert(:section, base_project: project)
      {:ok, section} = Sections.create_section_resources(section, publication)
      [base, same, other] = Enum.map(pages, & &1.resource_id)

      # The base and one target already share their settings; the other differs
      for resource_id <- [base, same] do
        put_section_resource_fields(
          Sections.get_section_resource(section.id, resource_id),
          %{max_attempts: 4}
        )
      end

      %{section: section, base: base, same: same, other: other}
    end

    test "records one event per assessment that changed and returns their count", %{
      section: section,
      base: base,
      same: same,
      other: other,
      context: context
    } do
      assert {:ok, 1} = Audited.bulk_apply_assessment_settings(context, section, base)

      changed = assert_audited(:assessment_settings_changed, resource_id: other)
      assert changed.changes["max_attempts"]["after"] == 4
      assert audit_events(:assessment_settings_changed, resource_id: same) == []
      assert audit_events(:assessment_settings_changed, resource_id: base) == []
      assert Sections.get_section_resource(section.id, other).max_attempts == 4
    end

    test "nothing is written when the events cannot be recorded", %{
      section: section,
      base: base,
      other: other,
      context: context
    } do
      before = Sections.get_section_resource(section.id, other).max_attempts
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn ->
                 Audited.bulk_apply_assessment_settings(context, section, base)
               end)

      assert Sections.get_section_resource(section.id, other).max_attempts == before
    end
  end

  describe "student exceptions" do
    test "creation records the overrides set, an update only what changed", %{
      section: section,
      resource_id: resource_id,
      context: context,
      instructor: instructor
    } do
      student = insert(:user)

      assert {:ok, _} =
               Audited.set_student_exception(context, section, resource_id, student.id, %{
                 "max_attempts" => 3,
                 "password" => "secret"
               })

      created =
        assert_audited(:student_exception_created,
          resource_id: resource_id,
          affected_user_id: student.id,
          actor: instructor
        )

      assert created.changes == %{
               "max_attempts" => %{"operation" => "set", "after" => 3},
               "password" => Changes.secret_record()
             }

      assert {:ok, _} =
               Audited.set_student_exception(context, section, resource_id, student.id, %{
                 max_attempts: 3,
                 late_policy: :disallow_late_start_and_late_submit
               })

      updated = assert_audited(:student_exception_updated, affected_user_id: student.id)
      assert Map.keys(updated.changes) == ["late_start", "late_submit"]

      # Setting the same values again records nothing
      assert {:ok, _} =
               Audited.set_student_exception(context, section, resource_id, student.id, %{
                 max_attempts: 3
               })

      assert length(audit_events(:student_exception_updated, affected_user_id: student.id)) == 1
    end

    test "a missing required field writes and records nothing", %{
      section: section,
      resource_id: resource_id,
      context: context
    } do
      student = insert(:user)

      assert {:error, %Ecto.Changeset{}} =
               Audited.set_student_exception(
                 context,
                 section,
                 resource_id,
                 student.id,
                 %{feedback_mode: :scheduled},
                 required: [:feedback_scheduled_date]
               )

      refute Repo.get_by(StudentException, user_id: student.id)
      assert audit_events(:student_exception_created, affected_user_id: student.id) == []
    end

    test "removal records one event per removed exception and skips students without one", %{
      section: section,
      resource_id: resource_id,
      context: context
    } do
      [first, second, without] = insert_list(3, :user)

      for student <- [first, second] do
        {:ok, _} =
          Audited.set_student_exception(context, section, resource_id, student.id, %{
            max_attempts: 2
          })
      end

      assert {:ok, 2} =
               Audited.remove_student_exceptions(context, section, resource_id, [
                 first.id,
                 second.id,
                 without.id
               ])

      for student <- [first, second] do
        deleted = assert_audited(:student_exception_deleted, affected_user_id: student.id)
        assert deleted.changes["max_attempts"] == %{"operation" => "set", "before" => 2}
      end

      assert audit_events(:student_exception_deleted, affected_user_id: without.id) == []
    end
  end

  defp capture_log_result(fun) do
    {result, _log} = ExUnit.CaptureLog.with_log(fun)
    result
  end
end
