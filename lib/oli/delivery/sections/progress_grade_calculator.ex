defmodule Oli.Delivery.Sections.ProgressGradeCalculator do
  @moduledoc """
  Module for calculating progress-based grades.

  Aggregates student progress across selected containers (units/modules),
  converts progress percentages to scores for LMS gradebook integration,
  and handles caching for performance optimization.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Sections.{Section, ProgressScoringSettings}
  alias Oli.Delivery.Sections.{ContainedPage, SectionResource}
  alias Oli.Delivery.Attempts.Core.ResourceAccess

  @doc """
  Calculates the progress-based grade for a single student in a section.

  Returns a map with progress percentage and calculated score.
  For backward compatibility, this aggregates all containers into a single grade.
  Use calculate_grade_per_container/2 for per-container grades.
  """
  def calculate_grade(section_id, user_id) do
    with {:ok, settings} <- get_progress_scoring_settings(section_id),
         true <- settings.enabled do
      progress_percentage =
        calculate_aggregate_progress(section_id, user_id, settings.container_ids)

      score =
        convert_progress_to_score(
          progress_percentage,
          settings.out_of,
          settings.include_zero_progress
        )

      {:ok,
       %{
         progress_percentage: progress_percentage,
         score: score,
         out_of: settings.out_of
       }}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :progress_scoring_disabled}
    end
  end

  @doc """
  Calculates progress-based grades per container for a single student.

  Returns a map where keys are container IDs and values are grade maps.
  This is used when each container has its own LMS line item.
  """
  def calculate_grade_per_container(section_id, user_id) do
    with {:ok, settings} <- get_progress_scoring_settings(section_id),
         true <- settings.enabled do
      container_grades =
        settings.container_ids
        |> Enum.map(fn container_id ->
          progress_percentage = calculate_container_progress(section_id, user_id, container_id)

          score =
            convert_progress_to_score(
              progress_percentage,
              settings.out_of,
              settings.include_zero_progress
            )

          {container_id,
           %{
             container_id: container_id,
             progress_percentage: progress_percentage,
             score: score,
             out_of: settings.out_of
           }}
        end)
        |> Enum.into(%{})

      {:ok, container_grades}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :progress_scoring_disabled}
    end
  end

  @doc """
  Calculates progress-based grades for multiple students in a section.

  Returns a map where keys are user IDs and values are grade maps.
  """
  def calculate_grades(section_id, user_ids) when is_list(user_ids) do
    with {:ok, settings} <- get_progress_scoring_settings(section_id),
         true <- settings.enabled do
      progress_map =
        calculate_aggregate_progress_bulk(section_id, user_ids, settings.container_ids)

      grades =
        Enum.reduce(user_ids, %{}, fn user_id, acc ->
          progress_percentage = Map.get(progress_map, user_id, 0.0)

          score =
            convert_progress_to_score(
              progress_percentage,
              settings.out_of,
              settings.include_zero_progress
            )

          Map.put(acc, user_id, %{
            progress_percentage: progress_percentage,
            score: score,
            out_of: settings.out_of
          })
        end)

      {:ok, grades}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :progress_scoring_disabled}
    end
  end

  @doc """
  Calculates aggregate progress for a student across selected containers.

  Returns the average progress across all pages within the selected containers.
  """
  def calculate_aggregate_progress(section_id, user_id, container_ids) do
    if Enum.empty?(container_ids) do
      0.0
    else
      # Get all pages within the selected containers
      page_ids = get_pages_in_containers(section_id, container_ids)

      if Enum.empty?(page_ids) do
        0.0
      else
        # Calculate average progress across all pages
        calculate_average_progress(section_id, user_id, page_ids)
      end
    end
  end

  @doc """
  Calculates progress for a student within a single container.

  Returns the average progress across all pages within the container.
  """
  def calculate_container_progress(section_id, user_id, container_id) do
    # Get all pages within this specific container
    page_ids = get_pages_in_container(section_id, container_id)

    if Enum.empty?(page_ids) do
      0.0
    else
      # Calculate average progress across the container's pages
      calculate_average_progress(section_id, user_id, page_ids)
    end
  end

  @doc """
  Calculates aggregate progress for multiple students across selected containers.

  Returns a map where keys are user IDs and values are progress percentages.
  """
  def calculate_aggregate_progress_bulk(section_id, user_ids, container_ids) do
    if Enum.empty?(container_ids) or Enum.empty?(user_ids) do
      Enum.reduce(user_ids, %{}, fn user_id, acc -> Map.put(acc, user_id, 0.0) end)
    else
      # Get all pages within the selected containers
      page_ids = get_pages_in_containers(section_id, container_ids)

      if Enum.empty?(page_ids) do
        Enum.reduce(user_ids, %{}, fn user_id, acc -> Map.put(acc, user_id, 0.0) end)
      else
        # Calculate average progress across all pages for all users
        calculate_average_progress_bulk(section_id, user_ids, page_ids)
      end
    end
  end

  @doc """
  Converts progress percentage to a score based on the configured scale.
  """
  def convert_progress_to_score(progress_percentage, out_of, include_zero_progress) do
    if not include_zero_progress and progress_percentage == 0.0 do
      # Don't assign any score for zero progress if configured
      nil
    else
      # Convert progress (0.0-1.0) to score (0.0-out_of)
      progress_percentage * out_of
    end
  end

  @doc """
  Validates if progress scoring is properly configured for a section.
  """
  def validate_configuration(section_id) do
    with {:ok, settings} <- get_progress_scoring_settings(section_id),
         true <- settings.enabled,
         false <- Enum.empty?(settings.container_ids),
         true <- settings.out_of > 0 do
      # Verify containers exist
      existing_containers = get_existing_container_ids(section_id)
      invalid_containers = Enum.reject(settings.container_ids, &(&1 in existing_containers))

      if Enum.empty?(invalid_containers) do
        {:ok, settings}
      else
        {:error, {:invalid_containers, invalid_containers}}
      end
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        case get_progress_scoring_settings(section_id) do
          {:ok, %{enabled: false}} -> {:error, :progress_scoring_disabled}
          _ -> {:error, :invalid_configuration}
        end
    end
  end

  # Private helper functions

  defp get_progress_scoring_settings(section_id) do
    case Repo.get(Section, section_id) do
      nil ->
        {:error, :section_not_found}

      %Section{progress_scoring_settings: nil} ->
        {:ok, %ProgressScoringSettings{}}

      %Section{progress_scoring_settings: settings_map} when is_map(settings_map) ->
        settings =
          struct(ProgressScoringSettings, atomize_keys(settings_map))

        {:ok, settings}

      _section ->
        {:ok, %ProgressScoringSettings{}}
    end
  end

  defp get_pages_in_containers(section_id, container_ids) do
    query =
      from cp in ContainedPage,
        where: cp.section_id == ^section_id,
        where: cp.container_id in ^container_ids,
        select: cp.page_id

    Repo.all(query)
  end

  defp get_pages_in_container(section_id, container_id) do
    query =
      from cp in ContainedPage,
        where: cp.section_id == ^section_id,
        where: cp.container_id == ^container_id,
        select: cp.page_id

    Repo.all(query)
  end

  defp calculate_average_progress(section_id, user_id, page_ids) do
    # Use a single query to get all progress values
    query =
      from ra in ResourceAccess,
        where: ra.section_id == ^section_id,
        where: ra.user_id == ^user_id,
        where: ra.resource_id in ^page_ids,
        select: ra.progress

    progress_values = Repo.all(query)

    if Enum.empty?(progress_values) do
      0.0
    else
      # Calculate average, treating missing entries as 0
      total_pages = length(page_ids)
      total_progress = Enum.sum(progress_values)

      # Average across all pages, including those with no progress recorded
      total_progress / total_pages
    end
  end

  defp calculate_average_progress_bulk(section_id, user_ids, page_ids) do
    # Get progress for all users and pages in a single query
    query =
      from ra in ResourceAccess,
        where: ra.section_id == ^section_id,
        where: ra.user_id in ^user_ids,
        where: ra.resource_id in ^page_ids,
        select: {ra.user_id, ra.progress}

    progress_data = Repo.all(query)
    total_pages = length(page_ids)

    # Group by user and calculate averages
    progress_by_user =
      progress_data
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {user_id, progress_values} ->
        total_progress = Enum.sum(progress_values)
        average_progress = total_progress / total_pages
        {user_id, average_progress}
      end)
      |> Enum.into(%{})

    # Ensure all users have an entry, defaulting to 0.0 for those with no progress
    Enum.reduce(user_ids, %{}, fn user_id, acc ->
      Map.put(acc, user_id, Map.get(progress_by_user, user_id, 0.0))
    end)
  end

  defp get_existing_container_ids(section_id) do
    query =
      from sr in SectionResource,
        join: cp in ContainedPage,
        on: cp.container_id == sr.resource_id,
        where: sr.section_id == ^section_id,
        where: cp.section_id == ^section_id,
        select: sr.resource_id,
        distinct: true

    Repo.all(query)
  end

  # Helper to convert string keys to atom keys for embedded schemas
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      {key, value} -> {key, value}
    end)
  rescue
    # Return original map if any key doesn't exist as atom
    ArgumentError -> map
  end
end
