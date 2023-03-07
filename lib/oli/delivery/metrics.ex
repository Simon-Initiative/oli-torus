defmodule Oli.Delivery.Metrics do

  import Ecto.Query, warn: false

  alias Oli.Repo

  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ActivityAttempt}
  alias Oli.Delivery.Attempts.Core

  @doc """
  Calculate the progress for a specific student, in all pages of a
  specific container.

  Ommitting the container_id (or specifying nil) calculates progress
  across the entire course section.

  This query leverages the `contained_pages` relation, which is always an
  up to date view of the structure of a course section. This allows this
  query to take into account structural chagnes as the result of course
  remix. The `contained_pages` relation is rebuilt after every remix.
  """
  def progress_for(section_id, user_id, container_id \\ nil) do

    filter_by_container =
      case container_id do
        nil ->
          dynamic([cp, _], is_nil(cp.container_id))

        _ ->
          dynamic([cp, _], cp.container_id == ^container_id)
      end

    query =
      ContainedPage
      |> join(:left, [cp], ra in ResourceAccess, on: cp.page_id == ra.resource_id and cp.section_id == ra.section_id and ra.user_id == ^user_id)
      |> where([cp, ra], cp.section_id == ^section_id)
      |> where(^filter_by_container)
      |> select([cp, ra], %{
        progress:
          fragment(
            "SUM(?) / COUNT(*)",
            ra.progress
          )
      })

    Repo.one(query).progress
  end

  @doc """
  Calculate the progress for a specific student, in all pages of a
  collection of containers.
  """
  def progress_across(section_id, container_ids, user_id) do
    query =
      ContainedPage
      |> join(:left, [cp], ra in ResourceAccess, on: cp.page_id == ra.resource_id and cp.section_id == ra.section_id and ra.user_id == ^user_id)
      |> where([cp, ra], cp.section_id == ^section_id and cp.container_id in ^container_ids)
      |> group_by([cp, ra], cp.container_id)
      |> select([cp, ra], %{
        container_id: cp.container_id,
        progress:
          fragment(
            "SUM(?) / COUNT(*)",
            ra.progress
          )
      })

    Repo.all(query)
  end

  @doc """
  Calculate the progress for all students, in all pages of a
  collection of containers.

  The last two parameters gives flexibility into excluding specific users
  from the calculation. This exists primarily to exclude instructors.
  `user_ids_to_ignore` can be an empty list, but `user_count` should always be the total
  number of enrolled students (excluding the count of those in the exlusion parameter).
  """
  def progress_across(section_id, container_ids, user_ids_to_ignore, user_count) do

    # If zero was passed in, we can allow the query to execute correctly and avoid a divide by zero by
    # simply changing it to 1
    user_count = max(user_count, 1)

    query =
      ContainedPage
      |> join(:left, [cp], ra in ResourceAccess, on: cp.page_id == ra.resource_id and cp.section_id == ra.section_id)
      |> join(:left, [cp, _], sr in SectionResource, on: cp.container_id == sr.resource_id and cp.section_id == sr.section_id)
      |> where([cp, ra, _], cp.section_id == ^section_id and cp.container_id in ^container_ids and ra.user_id not in ^user_ids_to_ignore)
      |> group_by([cp, ra, sr], [cp.container_id, sr.contained_page_count])
      |> select([cp, ra, sr], %{
        container_id: cp.container_id,
        progress:
          fragment(
            "SUM(?) / (? * ?)",
            ra.progress,
            sr.contained_page_count,
            ^user_count
          )
      })

    Repo.all(query)
  end

  @doc """
  Updates page progress to be 100% complete.
  """
  def mark_progress_completed(%ResourceAccess{} = ra) do
    Core.update_resource_access(ra, %{progress: 1.0})
  end

  @doc """
  Resets page progress to be 0% complete.
  """
  def reset_progress(%ResourceAccess{} = ra) do
    Core.update_resource_access(ra, %{progress: 0.0})
  end

  @doc """
  For an activity attempt specified by an attempt guid, calculate and set in the corresponding resource access
  record, the percentage complete for the related page. This calculation only needs to be performed after the
  evaluation of the first attempt for given activity.  This method should update exactly one record, the resource
  access for the page that this activity attempt ultimately pertains to (through its parent resource attempt).

  Can return one of:
  {:ok, :updated} -> Progress calculated and set
  {:ok, :noop} -> Noting needed to be done, since the attempt number was greater than 1
  {:error, :unexpected_update_count} -> 0 or more than 1 record would have been updated, rolled back
  {:error, e} -> An other error occurred, rolled back
  """
  def update_page_progress(activity_attempt_guid) when is_binary(activity_attempt_guid) do
    if Core.is_first_activity_attempt?(activity_attempt_guid) do
      do_update(activity_attempt_guid)
    else
      {:ok, :noop}
    end
  end

  def update_page_progress(%ActivityAttempt{attempt_number: 1, attempt_guid: attempt_guid}) do
    do_update(attempt_guid)
  end

  def update_page_progress(_) do
    {:ok, :noop}
  end

  defp do_update(activity_attempt_guid) do

    Oli.Repo.transaction(fn ->
      sql = """
        UPDATE
          resource_accesses
        SET
          progress = (SELECT
              COUNT(aa2.id) filter (WHERE aa2.lifecycle_state = 'evaluated' OR aa2.lifecycle_state = 'submitted')::float / COUNT(aa2.id)::float
            FROM activity_attempts as aa
            JOIN resource_attempts as ra ON ra.id = aa.resource_attempt_id
            JOIN activity_attempts as aa2 ON ra.id = aa2.resource_attempt_id
            WHERE aa.attempt_guid = $1 AND aa2.scoreable = true AND aa2.attempt_number = 1),
          updated_at = NOW()
        WHERE
          id =
            (SELECT
              resource_attempts.resource_access_id
            FROM resource_attempts
            JOIN activity_attempts ON resource_attempts.id = activity_attempts.resource_attempt_id
            WHERE activity_attempts.attempt_guid = $2
            LIMIT 1);
      """

      case Ecto.Adapters.SQL.query(Oli.Repo, sql, [activity_attempt_guid, activity_attempt_guid]) do
        {:ok, %{num_rows: 1}} -> :updated
        {:ok, %{num_rows: _}} -> Oli.Repo.rollback(:unexpected_update_count)
        {:error, e} -> Oli.Repo.rollback(e)
      end

    end)
  end

end
