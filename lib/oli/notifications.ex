defmodule Oli.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false

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
    system_message
    |> SystemMessage.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, system_message} ->
        schedule_message(system_message)
        {:ok, system_message}

      {:error, error} ->
        {:error, error}
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

  defp message_active_and_time_greater_than_now?(true, time) when not is_nil(time) do
    now = DateTime.utc_now()

    DateTime.compare(now, time) == :lt
  end

  defp message_active_and_time_greater_than_now?(_, _), do: false

  defp schedule_message(
         %SystemMessage{id: id, active: active, start: start_time, end: end_time} = system_message
       ) do
    remove_existing_message_jobs(id)

    if message_active_and_time_greater_than_now?(active, start_time) do
      %{id: id, system_message: system_message, display: true}
      |> Oli.Notifications.Worker.new(
        tags: ["message-#{id}"],
        scheduled_at: start_time,
        replace: [:scheduled_at]
      )
      |> Oban.insert()
    end

    if message_active_and_time_greater_than_now?(active, end_time) do
      %{id: id, system_message: system_message, display: false}
      |> Oli.Notifications.Worker.new(
        tags: ["message-#{id}"],
        scheduled_at: end_time,
        replace: [:scheduled_at]
      )
      |> Oban.insert()
    end
  end

  defp remove_existing_message_jobs(id) do
    message_tag = "message-#{id}"

    from(j in Oban.Job, where: j.worker == "Oli.Notifications.Worker" and ^message_tag in j.tags)
    |> Repo.delete_all()
  end
end
