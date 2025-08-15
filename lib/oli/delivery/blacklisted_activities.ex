defmodule Oli.Delivery.BlacklistedActivities do
  @moduledoc """
  Context for managing blacklisted activities in course sections.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.BlacklistedActivity

  @doc """
  Gets all blacklisted activity IDs for a section and selection.
  """
  def get_blacklisted_activity_ids(section_id, selection_id) do
    BlacklistedActivity
    |> where([b], b.section_id == ^section_id and b.selection_id == ^selection_id)
    |> select([b], b.activity_id)
    |> Repo.all()
  end

    @doc """
  Gets all blacklisted activities for the entire section.
  """
  def get_blacklisted_activities(section_id) do
    BlacklistedActivity
    |> where([b], b.section_id == ^section_id)
    |> Repo.all()
  end

  @doc """
  Checks if an activity is blacklisted for a section.
  """
  def is_blacklisted?(section_id, selection_id, activity_id) do
    BlacklistedActivity
    |> where([b], b.section_id == ^section_id and b.activity_id == ^activity_id and b.selection_id == ^selection_id)
    |> Repo.exists?()
  end

  @doc """
  Toggles the blacklist status of an activity for a section.
  Returns {:ok, :added} if the activity was blacklisted,
  or {:ok, :removed} if it was unblacklisted.
  """
  def toggle_blacklist(section_id, selection_id, activity_id) do
    case is_blacklisted?(section_id, selection_id, activity_id) do
      true ->
        remove_from_blacklist(section_id, selection_id, activity_id)
        {:ok, :removed}

      false ->
        add_to_blacklist(section_id, selection_id, activity_id)
        {:ok, :added}
    end
  end

  @doc """
  Adds an activity to the blacklist for a section.
  """
  def add_to_blacklist(section_id, selection_id, activity_id) do
    %BlacklistedActivity{}
    |> BlacklistedActivity.changeset(%{
      section_id: section_id,
      activity_id: activity_id,
      selection_id: selection_id
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Removes an activity from the blacklist for a section.
  """
  def remove_from_blacklist(section_id, selection_id, activity_id) do
    BlacklistedActivity
    |> where([b], b.section_id == ^section_id and b.activity_id == ^activity_id and b.selection_id == ^selection_id)
    |> Repo.delete_all()
  end

  @doc """
  Gets all blacklisted activities for a section with full records.
  """
  def list_blacklisted_activities(section_id, selection_id) do
    BlacklistedActivity
    |> where([b], b.section_id == ^section_id and b.selection_id == ^selection_id)
    |> Repo.all()
  end

  @doc """
  Bulk updates blacklisted activities for a section.
  Takes a list of activity IDs that should be blacklisted.
  """
  def bulk_update_blacklist(section_id, selection_id, activity_ids) do
    # Start a transaction
    Repo.transaction(fn ->
      # First, remove all existing blacklisted activities for this section
      BlacklistedActivity
      |> where([b], b.section_id == ^section_id)
      |> Repo.delete_all()

      # Then, insert the new ones
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        activity_ids
        |> Enum.map(fn activity_id ->
          %{
            section_id: section_id,
            activity_id: activity_id,
            selection_id: selection_id,
            inserted_at: now,
            updated_at: now
          }
        end)

      if length(entries) > 0 do
        Repo.insert_all(BlacklistedActivity, entries)
      end
    end)
  end
end
