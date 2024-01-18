defmodule Oli.Delivery.Settings.AutoSubmitCustodianTeset do
  use Oli.DataCase

  alias Oli.Delivery.Settings.AutoSubmitCustodian
  alias Oli.Delivery.Settings.StudentException

  def create_exception(map, page_key, user_key) do
    page = map[page_key]
    user = map[user_key]

    exception = %StudentException{
      section_id: map[:section].id,
      user_id: user.id,
      resource_id: page.resource.id,
      late_submit: :disallow,
      end_date: DateTime.utc_now() |> DateTime.add(10, :day) |> DateTime.truncate(:second)
    }

    {:ok, exception} = Oli.Repo.insert(exception)

    Map.put(map, :exception, exception)
  end

  def schedule_job(map, attempt_key, user_key) do
    attempt = map[attempt_key]
    section = map[:section]
    _user = map[user_key]

    tomorrow = DateTime.utc_now() |> DateTime.add(1, :day)

    {:ok, %{id: job_id}} =
      Oli.Delivery.Attempts.AutoSubmit.Worker.new(
        %{
          "attempt_guid" => attempt.attempt_guid,
          "section_slug" => section.slug,
          "datashop_session_id" => "this_does_not_matter"
        },
        scheduled_at: tomorrow
      )
      |> Oban.insert()

    {:ok, attempt} =
      Oli.Delivery.Attempts.Core.update_resource_attempt(attempt, %{auto_submit_job_id: job_id})

    Map.put(map, attempt_key, attempt)
  end

  describe "adjusting end_date" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_page(%{graded: true}, :graded_page1)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page1,
        :attempt1
      )
      |> schedule_job(:attempt1, :user1)
    end

    test "cancelling cancels the job and clears the job_id", %{
      section: section,
      attempt1: attempt1,
      graded_page1: graded_page1
    } do
      resource_id = graded_page1.resource.id

      {:ok, 1} = AutoSubmitCustodian.cancel(section.id, resource_id, nil)

      job = Repo.get!(Oban.Job, attempt1.auto_submit_job_id)
      assert job.state == "cancelled"

      attempt =
        Oli.Delivery.Attempts.Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)

      assert is_nil(attempt.auto_submit_job_id)
    end

    test "adjust creates a new job, cancels the old and updates the job_id", %{
      section: section,
      attempt1: attempt1,
      graded_page1: graded_page1
    } do
      resource_id = graded_page1.resource.id

      old = DateTime.utc_now() |> DateTime.add(1, :day)
      new = DateTime.utc_now() |> DateTime.add(2, :day)

      {:ok, 1} = AutoSubmitCustodian.adjust(section.id, resource_id, old, new, nil)

      job = Repo.get!(Oban.Job, attempt1.auto_submit_job_id)
      assert job.state == "cancelled"

      attempt =
        Oli.Delivery.Attempts.Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)

      refute is_nil(attempt.auto_submit_job_id)
      refute job.id == attempt.auto_submit_job_id

      job = Repo.get!(Oban.Job, attempt.auto_submit_job_id)
      assert job.state == "scheduled"
    end

    test "adjusting to clear the end date simply cancels", %{
      section: section,
      attempt1: attempt1,
      graded_page1: graded_page1
    } do
      resource_id = graded_page1.resource.id

      old = DateTime.utc_now() |> DateTime.add(1, :day)

      {:ok, 1} = AutoSubmitCustodian.adjust(section.id, resource_id, old, nil, nil)

      job = Repo.get!(Oban.Job, attempt1.auto_submit_job_id)
      assert job.state == "cancelled"

      attempt =
        Oli.Delivery.Attempts.Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)

      assert is_nil(attempt.auto_submit_job_id)
    end
  end

  describe "adjusting end_date in the face of student exceptions" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_page(%{graded: true}, :graded_page1)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page1,
        :attempt1
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user2,
        :graded_page1,
        :attempt2
      )
      |> schedule_job(:attempt1, :user1)
      |> schedule_job(:attempt2, :user2)
      |> create_exception(:graded_page1, :user2)
    end

    test "cancelling cancels the job and clears the job_id", %{
      section: section,
      attempt1: attempt1,
      graded_page1: graded_page1
    } do
      resource_id = graded_page1.resource.id

      {:ok, 1} = AutoSubmitCustodian.cancel(section.id, resource_id, nil)

      job = Repo.get!(Oban.Job, attempt1.auto_submit_job_id)
      assert job.state == "cancelled"

      attempt =
        Oli.Delivery.Attempts.Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)

      assert is_nil(attempt.auto_submit_job_id)
    end

    test "adjust creates a new job, cancels the old and updates the job_id", %{
      section: section,
      attempt1: attempt1,
      graded_page1: graded_page1
    } do
      resource_id = graded_page1.resource.id

      old = DateTime.utc_now() |> DateTime.add(1, :day)
      new = DateTime.utc_now() |> DateTime.add(2, :day)

      {:ok, 1} = AutoSubmitCustodian.adjust(section.id, resource_id, old, new, nil)

      job = Repo.get!(Oban.Job, attempt1.auto_submit_job_id)
      assert job.state == "cancelled"

      attempt =
        Oli.Delivery.Attempts.Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)

      refute is_nil(attempt.auto_submit_job_id)
      refute job.id == attempt.auto_submit_job_id

      job = Repo.get!(Oban.Job, attempt.auto_submit_job_id)
      assert job.state == "scheduled"
    end

    test "adjusting to clear the end date simply cancels", %{
      section: section,
      attempt1: attempt1,
      graded_page1: graded_page1
    } do
      resource_id = graded_page1.resource.id

      old = DateTime.utc_now() |> DateTime.add(1, :day)

      {:ok, 1} = AutoSubmitCustodian.adjust(section.id, resource_id, old, nil, nil)

      job = Repo.get!(Oban.Job, attempt1.auto_submit_job_id)
      assert job.state == "cancelled"

      attempt =
        Oli.Delivery.Attempts.Core.get_resource_attempt_by(attempt_guid: attempt1.attempt_guid)

      assert is_nil(attempt.auto_submit_job_id)
    end
  end
end
