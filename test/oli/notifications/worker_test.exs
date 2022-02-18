defmodule Oli.Groups.WorkerTest do
  use Oban.Testing, repo: Oli.Repo
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Notifications
  alias Oli.Notifications.Worker

  test "enqueues a job when updating a system message" do
    system_message = insert(:system_message)
    attrs = params_for(:active_system_message)

    {:ok, updated_system_message} = Notifications.update_system_message(system_message, attrs)

    assert_enqueued(
      worker: Worker,
      scheduled_at: updated_system_message.end,
      args: %{
        "system_message" => build_message_attrs(updated_system_message),
        "display" => false,
        id: updated_system_message.id
      }
    )
  end

  test "removes a job when setting a message to inactive" do
    system_message = insert(:active_system_message)

    {:ok, _} = Notifications.update_system_message(system_message, %{active: false})

    refute_enqueued(worker: Worker)
  end

  defp build_message_attrs(system_message) do
    %{
      "id" => system_message.id,
      "active" => system_message.active,
      "start" => system_message.start,
      "end" => system_message.end,
      "message" => system_message.message
    }
  end
end
