defmodule Oli.NotificationsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Notifications
  alias Oli.Notifications.SystemMessage
  alias Oli.Repo

  describe "system message" do
    test "create_system_message/1 with valid data creates a system message" do
      params = params_for(:system_message)

      assert {:ok, %SystemMessage{} = system_message} =
               Notifications.create_system_message(params)

      assert system_message.message == params.message
      assert system_message.active == params.active
      assert system_message.start == params.start
      assert system_message.end == params.end
    end

    test "create_system_message/1 without a message returns error changeset" do
      params = params_for(:system_message, %{message: ""})

      assert {:error, %Ecto.Changeset{}} = Notifications.create_system_message(params)
    end

    test "list_system_messages/0 returns all the system messages" do
      insert_list(3, :system_message)

      assert 3 = length(Notifications.list_system_messages())
    end

    test "list_system_messages/0 returns active messages first" do
      active_message = insert(:system_message)
      inactive_message = insert(:system_message, active: false)

      assert [active_message, inactive_message] == Notifications.list_system_messages()
    end

    test "list_active_system_messages/0 returns only messages that are currently active" do
      active_message = insert(:active_system_message)
      insert(:system_message)

      assert [active_message] == Notifications.list_active_system_messages()
    end

    test "get_system_message/1 returns a system_message when the id exists" do
      system_message = insert(:system_message)

      returned_system_message = Notifications.get_system_message(system_message.id)

      assert system_message == returned_system_message
    end

    test "get_system_message/1 returns nil if the system_message does not exist" do
      assert nil == Notifications.get_system_message(123)
    end

    test "update_system_message/2 updates the system_message successfully" do
      system_message = insert(:system_message)

      {:ok, updated_system_message} =
        Notifications.update_system_message(system_message, %{message: "new_message"})

      assert system_message.id == updated_system_message.id
      assert updated_system_message.message == "new_message"
    end

    test "update_system_message/2 does not update the system_message when there is an invalid field" do
      system_message = insert(:system_message)

      {:error, changeset} = Notifications.update_system_message(system_message, %{message: ""})
      {error, _} = changeset.errors[:message]

      refute changeset.valid?
      assert error =~ "can't be blank"
    end

    test "update_system_message/2 schedules jobs for displaying/hiding system messages" do
      system_message = insert(:system_message)
      now = DateTime.utc_now()
      start_date = DateTime.add(now, 3600)
      end_date = DateTime.add(now, 3700)

      {:ok, updated_system_message} =
        Notifications.update_system_message(system_message, %{message: "new_message", start: start_date, end: end_date})

      [start_job, end_job] =
        Ecto.Query.from(j in Oban.Job,
          where: j.worker == "Oli.Notifications.Worker",
          order_by: j.scheduled_at
        )
        |> Repo.all()

      assert start_job.state == "scheduled"
      assert DateTime.truncate(start_job.scheduled_at, :second) == updated_system_message.start

      assert end_job.state == "scheduled"
      assert DateTime.truncate(end_job.scheduled_at, :second) == updated_system_message.end
    end

    test "delete_system_message/1 deletes the message" do
      system_message = insert(:system_message)
      assert {:ok, deleted_system_message} = Notifications.delete_system_message(system_message)
      assert deleted_system_message.id == system_message.id
      assert Notifications.list_system_messages() == []
    end

    test "change_system_message/1 returns a system_message changeset" do
      system_message = insert(:system_message)
      assert %Ecto.Changeset{} = Notifications.change_system_message(system_message)
    end
  end
end
