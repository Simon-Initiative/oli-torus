defmodule Oli.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Oli.{Notifications.SystemMessage, Repo}

  # ------------------------------------------------------------
  # System Messages

  @doc """
  Returns the list of system_messages.

  ## Examples

      iex> list_system_messages()
      [%SystemMessage{}, ...]

  """
  def list_system_messages,
    do: Repo.all(from SystemMessage, order_by: [desc: :active, asc_nulls_first: :start])

  @doc """
  Returns the list of system_messages currently active.

  ## Examples

      iex> list_system_messages()
      [%SystemMessage{}, ...]

  """
  def list_active_system_messages do
    now = DateTime.utc_now()

    Repo.all(
      from(
        sm in SystemMessage,
        where: sm.active and ^now >= coalesce(sm.start, ^now) and ^now <= coalesce(sm.end, ^now),
        order_by: [desc: :updated_at]
      )
    )
  end

  @doc """
  Creates a system message.

  ## Examples

      iex> create_system_message(%{field: new_value})
      {:ok, %SystemMessage{}}

      iex> create_system_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_system_message(attrs \\ %{}) do
    %SystemMessage{}
    |> SystemMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a system message by id.

  ## Examples

      iex> get_system_message(1)
      %SystemMessage{}
      iex> get_system_message(123)
      nil
  """
  def get_system_message(id), do: Repo.get(SystemMessage, id)

  @doc """
  Updates a system message and schedules jobs for broadcasting message updates.

  ## Examples

      iex> update_system_message(system_message, %{name: new_value})
      {:ok, %SystemMessage{}}
      iex> update_system_message(system_message, %{name: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_system_message(%SystemMessage{} = system_message, attrs) do
    changeset = SystemMessage.changeset(system_message, attrs)

    res =
      Multi.new()
      |> Multi.update(:system_message, changeset)
      |> Multi.run(:schedule, &maybe_schedule_message(&1, &2))
      |> Repo.transaction()

    case res do
      {:ok, %{system_message: system_message}} ->
        {:ok, system_message}

      {:error, :system_message, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a system message.

  ## Examples

      iex> delete_system_message(system_message)
      {:ok, %SystemMessage{}}

      iex> delete_system_message(system_message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_system_message(%SystemMessage{} = system_message), do: Repo.delete(system_message)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking system message changes.

  ## Examples

      iex> change_system_message(system_message)
      %Ecto.Changeset{data: %SystemMessage{}}

  """
  def change_system_message(%SystemMessage{} = system_message, attrs \\ %{}) do
    SystemMessage.changeset(system_message, attrs)
  end

  defp remove_existing_message_jobs(id, repo) do
    message_tag = "message-#{id}"

    from(j in Oban.Job, where: j.worker == "Oli.Notifications.Worker" and ^message_tag in j.tags)
    |> repo.delete_all()
  end

  defp schedule_message_toggle_if_active(
         %SystemMessage{id: id, active: true} = system_message,
         time,
         display
       )
       when not is_nil(time) do
    now = DateTime.utc_now()

    if DateTime.compare(now, time) == :lt do
      %{id: id, system_message: system_message, display: display}
      |> Oli.Notifications.Worker.new(
        tags: ["message-#{id}"],
        scheduled_at: time,
        replace: [:scheduled_at]
      )
      |> Oban.insert()
    end
  end

  defp schedule_message_toggle_if_active(_system_message, _time, _display), do: nil

  defp maybe_schedule_message(
         repo,
         %{
           system_message:
             %SystemMessage{id: id, start: start_time, end: end_time} = system_message
         }
       ) do
    remove_existing_message_jobs(id, repo)

    schedule_message_toggle_if_active(system_message, start_time, true)
    schedule_message_toggle_if_active(system_message, end_time, false)

    {:ok, true}
  end
end
