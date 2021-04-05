defmodule Oli.Authoring.Locks do
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
  This implementation allows a user to acquire an already locked
  published_resource that is held by another user if that existing lock has expired. Locks
  are considered to be expired if they have not been updated for `@ttl` seconds.
  This handles the case that a user locks a resource and then abandons their
  editing session without closing their browser.

  ## Actions
  Three actions exist for a lock: `acquire`, `update` and `release`. Lock acquiring
  results in the published_resource record being stamped with the users id, but
  with an `nil` last updated at date.  Updating a lock sets the last updated at
  date. Releasing a lock sets both the user and last updated at to `nil`. Coupled
  with

  """

  import Ecto.Query, warn: false
  alias Oli.Publishing
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Authoring.Broadcaster

  # Locks that are not updated after 10 minutes are considered to be expired
  @ttl 10 * 60

  @doc """
  Attempts to acquire or update a lock for user `user_id` the published resource
  mapping defined by `publication_id` and `resource_id`.

  Returns:

  .`{:acquired}` if the lock was acquired
  .`{:error}` if an internal error was encountered
  .`{:lock_not_acquired, {user_email, date_time}}` the date and user id of the existing lock

  """
  @spec acquire(number, number, number) ::
          {:error}
          | {:acquired}
          | {:lock_not_acquired,
             {String.t(),
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
  def acquire(publication_id, resource_id, user_id) do

    # Get the published_resource that pertains to this publication and resource
    case Publishing.get_published_resource!(publication_id, resource_id) |> Repo.preload([:author]) do

      # Acquire the lock if held already by this user
      %{locked_by_id: ^user_id} = mapping -> lock_action(mapping, user_id, &always?/1, {:acquired}, {:acquired}, nil)

      # Acquire the lock if no user has this mapping locked
      %{locked_by_id: nil} = mapping -> lock_action(mapping, user_id, &always?/1, {:acquired}, {:acquired}, nil)

      # Otherwise, another user may have this locked, acquire it if
      # the lock is expired
      %{lock_updated_at: lock_updated_at} = mapping ->
        lock_action(mapping, user_id, &expired?/1, {:acquired}, {:lock_not_acquired, {mapping.author.email, lock_updated_at}}, nil)
    end
  end

  @doc """
  Attempts to acquire or update a lock for user `user_id` the published resource mapping
  defined by `publication_id` and `resource_id`.

  Returns:

  .`{:acquired}` if the lock was acquired
  .`{:updated}` if the lock was updated
  .`{:error}` if an internal error was encountered
  .`{:lock_not_acquired, {user_email, date_time}}` the date and user id of the existing lock

  """
  @spec update(number, number, number) ::
          {:error, any()}
          | {:acquired}
          | {:updated}
          | {:lock_not_acquired,
             {String.t(),
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
  def update(publication_id, resource_id, user_id) do

    # Get the mapping that pertains to this publication and resource
    case Publishing.get_published_resource!(publication_id, resource_id) |> Repo.preload([:author]) do

      # Acquire the lock if held already by this user and the lock is expired or its last_updated_date is empty
      # otherwise, simply update it
      %{locked_by_id: ^user_id} = mapping -> lock_action(mapping, user_id, &expired_or_empty_predicate?/1, {:acquired}, {:updated}, now())

      # Otherwise, another user may have this locked, a new revision was created after the user
      # acquired the lock, or it was locked by this
      # user and it expired and an interleaving lock, redit, release by another user
      # has taken place.  We must not acquire here since this could lead to lost changes as
      # the client has a copy of content in client-side memory and is seeking to update this
      # revision.
      %{lock_updated_at: lock_updated_at} = mapping ->
        # The :lock_not_acquired message shows the author's email if a lock is present. Otherwise,
        # it just shows a generic message
        {:lock_not_acquired, {
          if is_nil(mapping.author) do "another author" else mapping.author.email end,
          lock_updated_at
        }}
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
    case Publishing.get_published_resource!(publication_id, resource_id) do
      %{locked_by_id: ^user_id} = mapping -> release_lock(mapping)
      _ -> {:lock_not_held}
    end
  end

  @doc """
  Releases all locks for revisions in the supplied publication.
  This removes the `locked_by_id` and `lock_updated_at` fields.

  Returns:
  .`{number, nil | returned data}` where number is the number of rows updated
  """
  @spec release_all(binary) :: {number, nil | term()}
  def release_all(publication_id) do
    from(pr in PublishedResource,
      where: pr.publication_id == ^publication_id and not is_nil(pr.locked_by_id),
      select: pr)
    |> Repo.update_all(set: [locked_by_id: nil, lock_updated_at: nil])
  end

  defp now() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    datetime
  end

  defp lock_action(published_resource, current_user_id, predicate, success_result, failure_result, lock_updated_at) do
    case predicate.(published_resource) do
      true -> case Publishing.update_published_resource(published_resource, %{ locked_by_id: current_user_id, lock_updated_at: lock_updated_at}) do
        {:ok, _} ->
          Broadcaster.broadcast_lock_acquired(published_resource.publication_id, published_resource.resource_id, current_user_id)
          success_result
        {:error, _} -> {:error}
      end
      false -> failure_result
    end
  end

  defp always?(_published_resource) do
    true
  end

  defp expired?(%{ lock_updated_at: lock_updated_at, updated_at: updated_at}) do

    # A lock is expired if a diff from now vs lock_updated_at field exceeds the ttl
    # If a no edit has been made, we use the timestamp updated_at instead for this calculation
    to_use = case lock_updated_at do
      nil -> updated_at
      _ -> lock_updated_at
    end

    NaiveDateTime.diff(now(), to_use) > @ttl
  end

  def expired_or_empty?(%{ locked_by_id: locked_by_id} = published_resource) do
    locked_by_id == nil or expired?(published_resource)
  end

  def expired_or_empty_predicate?(%{ lock_updated_at: lock_updated_at} = published_resource) do
    lock_updated_at == nil or expired?(published_resource)
  end

  defp release_lock(published_resource) do
    case Publishing.update_published_resource(published_resource, %{ locked_by_id: nil, lock_updated_at: nil}) do
      {:ok, _} ->
        Broadcaster.broadcast_lock_released(published_resource.publication_id, published_resource.resource_id)
        {:ok}
      {:error, _} -> {:error}
    end
  end

end
