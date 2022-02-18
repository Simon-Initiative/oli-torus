defmodule Oli.Groups.SystemMessageTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Notifications.SystemMessage

  describe "changeset/2" do
    test "changeset should be invalid if message is empty" do
      changeset =
        build(:system_message, %{message: ""})
        |> SystemMessage.changeset()

      refute changeset.valid?
    end

    test "changeset should be invalid if message is too long" do
      message = String.duplicate("a", 150)

      changeset =
        build(:system_message)
        |> SystemMessage.changeset(%{message: message})

      refute changeset.valid?
    end

    test "changeset should be invalid if start date is after end date" do
      {:ok, start_date, _timezone} = DateTime.from_iso8601("2022-02-10 20:30:00Z")
      {:ok, end_date, _timezone} = DateTime.from_iso8601("2022-02-09 20:30:00Z")

      changeset =
        build(:system_message)
        |> SystemMessage.changeset(%{start: start_date, end: end_date})

      refute changeset.valid?
    end
  end
end
