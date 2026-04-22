defmodule Oli.Delivery.Settings.StudentExceptionsTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Delivery.Attempts.AutoSubmit.Worker
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Settings.StudentExceptions
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Seeder

  describe "set_exception/4 auto submit maintenance" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_page(%{graded: true}, :graded_page1)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1, lifecycle_state: :active},
        :user1,
        :graded_page1,
        :attempt1
      )
      |> configure_section_settings(:graded_page1, %{
        end_date: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second),
        late_start: :disallow,
        late_submit: :disallow,
        scheduling_type: :due_by,
        time_limit: 0,
        grace_period: 0
      })
      |> schedule_job(:attempt1)
    end

    test "reschedules an existing auto submit job when a sparse exception due date changes", %{
      section: section,
      user1: user,
      graded_page1: graded_page1,
      attempt1: attempt
    } do
      resource_id = graded_page1.resource.id
      new_due_date = DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.truncate(:second)

      assert {:ok, exception} = StudentExceptions.set_exception(section, resource_id, user.id)
      assert is_nil(exception.late_submit)

      old_job_id = attempt.auto_submit_job_id

      assert {:ok, _updated_exception} =
               StudentExceptions.set_exception(section, resource_id, user.id, %{
                 due_date: new_due_date
               })

      cancelled_job = Repo.get!(Oban.Job, old_job_id)
      assert cancelled_job.state == "cancelled"

      updated_attempt = Core.get_resource_attempt_by(attempt_guid: attempt.attempt_guid)
      refute is_nil(updated_attempt.auto_submit_job_id)
      refute updated_attempt.auto_submit_job_id == old_job_id

      new_job = Repo.get!(Oban.Job, updated_attempt.auto_submit_job_id)
      assert new_job.state == "scheduled"
      assert DateTime.compare(new_job.scheduled_at, Worker.add_slack(new_due_date)) == :eq
    end

    test "cancels an existing auto submit job when an exception changes late policy to allow", %{
      section: section,
      user1: user,
      graded_page1: graded_page1,
      attempt1: attempt
    } do
      resource_id = graded_page1.resource.id

      assert {:ok, exception} = StudentExceptions.set_exception(section, resource_id, user.id)
      assert is_nil(exception.late_submit)

      old_job_id = attempt.auto_submit_job_id

      assert {:ok, _updated_exception} =
               StudentExceptions.set_exception(section, resource_id, user.id, %{
                 late_policy: :allow_late_start_and_late_submit
               })

      cancelled_job = Repo.get!(Oban.Job, old_job_id)
      assert cancelled_job.state == "cancelled"

      updated_attempt = Core.get_resource_attempt_by(attempt_guid: attempt.attempt_guid)
      assert is_nil(updated_attempt.auto_submit_job_id)
    end

    test "creates an auto submit job when an exception changes late policy to disallow", %{
      section: section,
      user1: user,
      graded_page1: graded_page1,
      attempt1: attempt
    } do
      resource_id = graded_page1.resource.id

      section_resource = Sections.get_section_resource(section.id, resource_id)

      assert {:ok, _section_resource} =
               Sections.update_section_resource(section_resource, %{
                 late_start: :allow,
                 late_submit: :allow
               })

      assert {:ok, 1} =
               Oli.Delivery.Settings.AutoSubmitCustodian.cancel(section.id, resource_id, user.id)

      assert {:ok, exception} = StudentExceptions.set_exception(section, resource_id, user.id)
      assert is_nil(exception.late_submit)

      attempt = Core.get_resource_attempt_by(attempt_guid: attempt.attempt_guid)
      assert is_nil(attempt.auto_submit_job_id)

      assert {:ok, _updated_exception} =
               StudentExceptions.set_exception(section, resource_id, user.id, %{
                 late_policy: :disallow_late_start_and_late_submit
               })

      updated_attempt = Core.get_resource_attempt_by(attempt_guid: attempt.attempt_guid)
      refute is_nil(updated_attempt.auto_submit_job_id)

      new_job = Repo.get!(Oban.Job, updated_attempt.auto_submit_job_id)
      assert new_job.state == "scheduled"

      effective_settings = Settings.get_combined_settings(updated_attempt)

      expected_deadline =
        Settings.determine_effective_deadline(updated_attempt, effective_settings)

      assert DateTime.compare(new_job.scheduled_at, Worker.add_slack(expected_deadline)) == :eq
    end
  end

  defp configure_section_settings(map, page_key, attrs) do
    resource = map[page_key].resource
    section_resource = Sections.get_section_resource(map.section.id, resource.id)
    {:ok, _section_resource} = Sections.update_section_resource(section_resource, attrs)
    map
  end

  defp schedule_job(map, attempt_key) do
    attempt = map[attempt_key]
    section = map.section
    effective_settings = Settings.get_combined_settings(attempt)
    effective_deadline = Settings.determine_effective_deadline(attempt, effective_settings)

    {:ok, job_id} =
      Worker.maybe_schedule_auto_submit(
        effective_settings,
        section.slug,
        attempt,
        "this_does_not_matter"
      )

    assert DateTime.compare(effective_deadline, DateTime.utc_now()) == :gt

    {:ok, attempt} = Core.update_resource_attempt(attempt, %{auto_submit_job_id: job_id})

    Map.put(map, attempt_key, attempt)
  end
end
