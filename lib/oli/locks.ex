defmodule Oli.Locks do

  alias Oli.Publishing
  alias Oli.Publishing.ResourceMapping

  # Locks that are not updated after 10 minutes are considered to be expired
  @ttl 10 * 60

  def acquire(publication, resource, user) do
    case Publishing.get_resource_mapping!(publication, resource) do
      %{locked_by_id: ^user} = mapping -> acquire_lock(mapping, user)
      %{locked_by_id: nil} = mapping -> acquire_lock(mapping, user)
      mapping -> acquire_lock_if_expired(mapping, user)
    end
  end

  def release(publication, resource, user) do
    case Publishing.get_resource_mapping!(publication, resource) do
      %{locked_by_id: ^user} = mapping -> release_lock(mapping)
      _ -> {:lock_not_held}
    end
  end

  defp now() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    datetime
  end

  defp acquire_lock(mapping, user) do
    case Publishing.update_resource_mapping(mapping, %{ locked_by_id: user, lock_updated_at: now()}) do
      {:ok, _} -> {:ok}
      {:error, _} -> {:error}
    end
  end

  defp acquire_lock_if_expired(%ResourceMapping{ locked_by_id: locked_by_id, lock_updated_at: lock_updated_at } = mapping, user) do

    if NaiveDateTime.diff(now(), lock_updated_at) > @ttl do
      acquire_lock(mapping, user)
    else
      {:lock_not_acquired, {locked_by_id, lock_updated_at}}
    end
  end

  defp release_lock(mapping) do
    case Publishing.update_resource_mapping(mapping, %{ locked_by_id: nil, locked_at: nil}) do
      {:ok, _} -> {:ok}
      {:error, _} -> {:error}
    end
  end

end
