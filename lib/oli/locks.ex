defmodule Oli.Locks do
  @moduledoc """
  This module provides an interface to durable write locks. These locks are
  durable in the sense that they will survive server restarts given that
  they are stored in the database.

  ## Scoping
  Locks are scoped to publication and resource. This allows the implementation
  to support multiple locks per resource per project. This is necessary
  to allow the situation where an author (from the project) is editing a
  resource concurrent to an instructor (from a section) editing that same
  resource.  Each edit in this example would pertain to a differrent publication,
  thus the scoping of locks to publication and resource.

  ## Lock Expiration
  This implementation allows a user to acquire an already locked resource
  mapping that is held by another user if that existing lock has expired. Locks
  are considered to be expired if they have not been updated for `@ttl` seconds.
  This handles the case that a user locks a resource and then abandons their
  editing session without closing their browser.

  ## Actions
  Only two actions exist for a lock: `acquire_or_update` and `release`. It is
  safe - and by design - to call `acquire_or_update` repeatedly without calling
  release.  This is how a lock's last updated date and time is updated and thus
  how a lock is does not expire.

  """

  alias Oli.Publishing
  alias Oli.Publishing.ResourceMapping

  # Locks that are not updated after 10 minutes are considered to be expired
  @ttl 10 * 60

  @doc """
  Attempts to acquire or update a lock for user `user_id` the resource mapping
  defined by `publication_id` and `resource_id`.

  Returns:

  .`{:acquired}` if the lock was acquired
  .`{:updated}` if the lock was updated
  .`{:error}` if an internal error was encountered
  .`{:lock_not_acquired, {user_id, date_time}}` the date and user id of the existing lock

  """
  @spec acquire_or_update(number, number, number) ::
          {:error}
          | {:acquired}
          | {:updated}
          | {:lock_not_acquired,
             {number,
              %{
                calendar: atom,
                day: any,
                hour: any,
                microsecond: any,
                minute: any,
                month: any,
                second: any,
                year: any
              }}}
  def acquire_or_update(publication_id, resource_id, user_id) do

    # Get the mapping that pertains to this publication and resource
    case Publishing.get_resource_mapping!(publication_id, resource_id) do

      # Acquire / update the lock if held already by this user
      %{locked_by_id: ^user_id} = mapping -> acquire_or_update_lock(mapping, user_id)

      # Acquire the lock if no user has this mapping locked
      %{locked_by_id: nil} = mapping -> acquire_lock(mapping, user_id, {:acquired})

      # Otherwise, another user may have this locked, acquire it if
      # the lock is expired
      mapping -> acquire_or_not(mapping, user_id)
    end
  end

  @doc """
  Releases a lock held by user `user_id` the resource mapping
  defined by `publication_id` and `resource_id`.

  Returns:

  .`{:ok}` if the lock was released
  .`{:error}` if an internal error was encountered
  .`{:lock_not_held}` if the lock was not held by this user

  """
  @spec release(number, number, number) :: {:error} | {:lock_not_held} | {:ok}
  def release(publication_id, resource_id, user_id) do
    case Publishing.get_resource_mapping!(publication_id, resource_id) do
      %{locked_by_id: ^user_id} = mapping -> release_lock(mapping)
      _ -> {:lock_not_held}
    end
  end

  defp now() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    datetime
  end

  defp acquire_lock(mapping, user, result) do
    case Publishing.update_resource_mapping(mapping, %{ locked_by_id: user, lock_updated_at: now()}) do
      {:ok, _} -> result
      {:error, _} -> {:error}
    end
  end

  defp acquire_or_update_lock(%ResourceMapping{ lock_updated_at: lock_updated_at } = mapping, user) do

    if NaiveDateTime.diff(now(), lock_updated_at) > @ttl do
      acquire_lock(mapping, user, {:acquired})
    else
      acquire_lock(mapping, user, {:updated})
    end
  end

  defp acquire_or_not(%ResourceMapping{ locked_by_id: locked_by_id, lock_updated_at: lock_updated_at } = mapping, user) do

    if NaiveDateTime.diff(now(), lock_updated_at) > @ttl do
      acquire_lock(mapping, user, {:acquired})
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
