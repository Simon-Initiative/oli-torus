defmodule Oli.Delivery.Sections.ProgressScoringManager do
  @moduledoc """
  Context for managing progress scoring configurations and operations.

  Provides CRUD operations for progress scoring settings within sections,
  validation of container selections, and coordination with grade sync.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo

  alias Oli.Delivery.Sections.{
    Section,
    ProgressScoringSettings,
    ProgressGradeSyncLog,
    SectionResourceDepot
  }

  @doc """
  Gets the progress scoring settings for a section.

  Returns the embedded ProgressScoringSettings or a default struct if none exists.
  """
  def get_progress_scoring_settings(section_id) do
    case Repo.get(Section, section_id) do
      nil ->
        {:error, :section_not_found}

      %Section{progress_scoring_settings: nil} ->
        {:ok, %ProgressScoringSettings{}}

      %Section{progress_scoring_settings: settings_map} ->
        settings =
          %ProgressScoringSettings{}
          |> ProgressScoringSettings.changeset(settings_map)
          |> Ecto.Changeset.apply_changes()

        {:ok, settings}
    end
  end

  @doc """
  Updates the progress scoring settings for a section.

  Validates the settings and ensures selected containers exist within the section.
  """
  def update_progress_scoring_settings(section_id, attrs) do
    with {:ok, section} <- get_section_with_containers(section_id),
         changeset <- validate_settings_changeset(attrs, section),
         true <- changeset.valid? do
      section
      |> Section.changeset(%{progress_scoring_settings: changeset.changes})
      |> Repo.update()
      |> case do
        {:ok, updated_section} ->
          {:ok, extract_progress_scoring_settings(updated_section)}

        error ->
          error
      end
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        changeset = validate_settings_changeset(attrs, nil)
        {:error, changeset}
    end
  end

  @doc """
  Enables progress scoring for a section with the provided configuration.
  """
  def enable_progress_scoring(section_id, attrs) do
    attrs = Map.put(attrs, :enabled, true)

    with {:ok, section} <- get_section_with_containers(section_id),
         changeset <- ProgressScoringSettings.enable_changeset(%ProgressScoringSettings{}, attrs),
         true <- changeset.valid?,
         :ok <- validate_container_exists(changeset.changes.container_ids, section) do
      settings_map = Ecto.Changeset.apply_changes(changeset) |> Map.from_struct()

      section
      |> Section.changeset(%{progress_scoring_settings: settings_map})
      |> Repo.update()
      |> case do
        {:ok, updated_section} ->
          {:ok, extract_progress_scoring_settings(updated_section)}

        error ->
          error
      end
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        changeset = ProgressScoringSettings.enable_changeset(%ProgressScoringSettings{}, attrs)
        {:error, changeset}
    end
  end

  @doc """
  Disables progress scoring for a section.
  """
  def disable_progress_scoring(section_id) do
    with {:ok, section} <- get_section(section_id) do
      settings_map = %{"enabled" => false}

      section
      |> Section.changeset(%{progress_scoring_settings: settings_map})
      |> Repo.update()
      |> case do
        {:ok, updated_section} ->
          {:ok, extract_progress_scoring_settings(updated_section)}

        error ->
          error
      end
    end
  end

  @doc """
  Gets available containers (units or modules) for progress scoring configuration.

  Returns containers based on the specified hierarchy type.
  """
  def get_available_containers(section_id, hierarchy_type) do
    if hierarchy_type in [:units, :modules] do
      # Use SectionResourceDepot for fast cached access to containers
      level_filter =
        case hierarchy_type do
          :units ->
            [numbering_level: 1]

          :modules ->
            [numbering_level: 2]
            # Note: if both are needed, use numbering_level: {:in, [1, 2]}
        end

      containers =
        SectionResourceDepot.containers(section_id, level_filter)
        |> Enum.map(fn sr ->
          %{
            id: sr.resource_id,
            title: sr.title,
            numbering: sr.numbering_index
          }
        end)

      {:ok, containers}
    else
      {:error, :invalid_hierarchy_type}
    end
  end

  @doc """
  Gets recent sync logs for a section.
  """
  def get_recent_sync_logs(section_id, limit \\ 50) do
    query =
      from log in ProgressGradeSyncLog,
        where: log.section_id == ^section_id,
        order_by: [desc: log.inserted_at],
        limit: ^limit,
        preload: [:user]

    {:ok, Repo.all(query)}
  end

  @doc """
  Gets pending sync logs for a section.
  """
  def get_pending_sync_logs(section_id) do
    query =
      from log in ProgressGradeSyncLog,
        where: log.section_id == ^section_id,
        where: log.sync_status == :pending,
        order_by: [asc: log.inserted_at],
        preload: [:user]

    {:ok, Repo.all(query)}
  end

  @doc """
  Gets all section IDs that have progress scoring enabled.
  """
  def get_enabled_sections do
    try do
      query =
        from s in Section,
          where: fragment("?->>'enabled' = 'true'", s.progress_scoring_settings),
          select: s.id

      {:ok, Repo.all(query)}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Creates a pending sync log entry.
  """
  def create_pending_sync_log(section_id, user_id, progress_percentage, score, out_of) do
    ProgressGradeSyncLog.pending_changeset(
      section_id,
      user_id,
      progress_percentage,
      score,
      out_of
    )
    |> Repo.insert()
  end

  @doc """
  Updates a sync log to success status.
  """
  def mark_sync_success(sync_log) do
    sync_log
    |> ProgressGradeSyncLog.success_changeset()
    |> Repo.update()
  end

  @doc """
  Updates a sync log to failed status with error details.
  """
  def mark_sync_failure(sync_log, error_details, attempt_number \\ nil) do
    sync_log
    |> ProgressGradeSyncLog.failure_changeset(error_details, attempt_number)
    |> Repo.update()
  end

  # Private helper functions

  defp get_section(section_id) do
    case Repo.get(Section, section_id) do
      nil -> {:error, :section_not_found}
      section -> {:ok, section}
    end
  end

  defp get_section_with_containers(section_id) do
    query =
      from s in Section,
        where: s.id == ^section_id,
        preload: [section_resources: :resource]

    case Repo.one(query) do
      nil -> {:error, :section_not_found}
      section -> {:ok, section}
    end
  end

  defp validate_settings_changeset(attrs, section) do
    changeset = ProgressScoringSettings.changeset(%ProgressScoringSettings{}, attrs)

    if changeset.valid? && changeset.changes[:enabled] == true && section do
      container_ids = changeset.changes[:container_ids] || []

      case validate_container_exists(container_ids, section) do
        :ok ->
          changeset

        {:error, _reason} ->
          Ecto.Changeset.add_error(changeset, :container_ids, "contains invalid container IDs")
      end
    else
      changeset
    end
  end

  defp validate_container_exists(container_ids, section) when is_list(container_ids) do
    existing_ids =
      section.section_resources
      |> Enum.map(& &1.resource_id)
      |> MapSet.new()

    provided_ids = MapSet.new(container_ids)

    if MapSet.subset?(provided_ids, existing_ids) do
      :ok
    else
      invalid_ids = MapSet.difference(provided_ids, existing_ids) |> Enum.to_list()
      {:error, {:invalid_container_ids, invalid_ids}}
    end
  end

  defp extract_progress_scoring_settings(%Section{progress_scoring_settings: settings_map})
       when is_map(settings_map) do
    %ProgressScoringSettings{}
    |> ProgressScoringSettings.changeset(settings_map)
    |> Ecto.Changeset.apply_changes()
  end

  defp extract_progress_scoring_settings(_section) do
    %ProgressScoringSettings{}
  end
end
