defmodule Oli.Delivery.Sections.ProgressGradeLineItem do
  @moduledoc """
  Module for managing LMS line items for progress scores.

  Handles creation and management of LMS gradebook line items for progress-based scoring.
  Each container (unit/module) gets its own line item with a deterministic resource ID
  based on the container ID, eliminating the need to store line item IDs.
  """

  require Logger

  alias Lti_1p3.Tool.Services.AGS
  alias Oli.Delivery.Sections.{ProgressScoringSettings, SectionResourceDepot}

  @doc """
  Generates a deterministic resource ID for a container's progress line item.

  Using a simple format that includes the container ID ensures uniqueness
  and allows the LMS to return the same line item for repeated requests.
  """
  def progress_score_resource_id(container_id) do
    "torus_progress_#{container_id}"
  end

  @doc """
  Fetches or creates a line item for a specific container.

  This is the main function used during grade sync to get the appropriate 
  line item for a student's progress in a specific container.
  """
  def fetch_or_create_line_item_for_container(section, container_id, access_token) do
    with {:ok, settings} <- get_progress_scoring_settings(section),
         true <- settings.enabled,
         true <- section.grade_passback_enabled,
         true <- container_id in settings.container_ids,
         {:ok, container} <- get_container_info(section.id, container_id) do
      resource_id = progress_score_resource_id(container_id)
      label = progress_score_label(section.title, container.title, settings.hierarchy_type)
      out_of_provider = fn -> settings.out_of end

      AGS.fetch_or_create_line_item(
        section.line_items_service_url,
        resource_id,
        out_of_provider,
        label,
        access_token
      )
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :progress_scoring_disabled_or_container_not_selected}
    end
  end

  @doc """
  Fetches or creates line items for all selected containers in the section.

  Returns a map of container_id => line_item for each configured container.
  This is useful for bulk operations or initial setup.
  """
  def fetch_or_create_all_line_items(section, access_token) do
    with {:ok, settings} <- get_progress_scoring_settings(section),
         true <- settings.enabled,
         true <- section.grade_passback_enabled,
         {:ok, containers} <- get_selected_containers(section, settings) do
      # Create or fetch line items for each container
      line_items_result =
        containers
        |> Enum.reduce({:ok, %{}}, fn container, acc ->
          case acc do
            {:ok, line_items_map} ->
              resource_id = progress_score_resource_id(container.id)

              label =
                progress_score_label(section.title, container.title, settings.hierarchy_type)

              out_of_provider = fn -> settings.out_of end

              case AGS.fetch_or_create_line_item(
                     section.line_items_service_url,
                     resource_id,
                     out_of_provider,
                     label,
                     access_token
                   ) do
                {:ok, line_item} ->
                  {:ok, Map.put(line_items_map, container.id, line_item)}

                {:error, reason} ->
                  Logger.error(
                    "Failed to create line item for container #{container.id}: #{inspect(reason)}"
                  )

                  {:error, reason}
              end

            error ->
              error
          end
        end)

      line_items_result
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :progress_scoring_disabled}
    end
  end

  @doc """
  Generates the label for a container's progress score line item.
  """
  def progress_score_label(section_title, container_title, hierarchy_type) do
    hierarchy_name =
      case hierarchy_type do
        :units -> "Unit"
        :modules -> "Module"
        _ -> "Container"
      end

    "#{section_title} - #{hierarchy_name}: #{container_title}"
  end

  @doc """
  Gets line item information for all configured containers.

  Since resource IDs are deterministic, we can generate the expected
  line item info without needing to store IDs.
  """
  def get_all_line_items_info(section) do
    with {:ok, settings} <- get_progress_scoring_settings(section),
         true <- settings.enabled,
         {:ok, containers} <- get_selected_containers(section, settings) do
      line_items_info =
        containers
        |> Enum.map(fn container ->
          %{
            container_id: container.id,
            container_title: container.title,
            resource_id: progress_score_resource_id(container.id),
            label: progress_score_label(section.title, container.title, settings.hierarchy_type),
            out_of: settings.out_of
          }
        end)

      {:ok, line_items_info}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :progress_scoring_disabled}
    end
  end

  @doc """
  Validates that a section has progress scoring properly configured.
  """
  def validate_configuration(section) do
    with {:ok, settings} <- get_progress_scoring_settings(section),
         true <- settings.enabled,
         true <- section.grade_passback_enabled,
         false <- Enum.empty?(settings.container_ids) do
      {:ok, :valid}
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        cond do
          not get_enabled?(section) -> {:error, :progress_scoring_disabled}
          not section.grade_passback_enabled -> {:error, :grade_passback_disabled}
          true -> {:error, :no_containers_selected}
        end
    end
  end

  # Private helper functions

  defp get_selected_containers(section, settings) do
    case settings.container_ids do
      [] ->
        {:error, :no_containers_selected}

      container_ids ->
        containers =
          SectionResourceDepot.get_pages(section.id, container_ids)
          |> Enum.map(fn sr ->
            %{
              id: sr.resource_id,
              title: sr.title,
              numbering: sr.numbering_index
            }
          end)

        {:ok, containers}
    end
  end

  defp get_container_info(section_id, container_id) do
    case SectionResourceDepot.get_section_resource(section_id, container_id) do
      nil ->
        {:error, :container_not_found}

      sr ->
        {:ok,
         %{
           id: sr.resource_id,
           title: sr.title,
           numbering: sr.numbering_index
         }}
    end
  end

  defp get_progress_scoring_settings(section) do
    case section.progress_scoring_settings do
      nil ->
        {:ok, %ProgressScoringSettings{}}

      settings_map when is_map(settings_map) ->
        settings = struct(ProgressScoringSettings, atomize_keys(settings_map))
        {:ok, settings}

      _ ->
        {:ok, %ProgressScoringSettings{}}
    end
  end

  defp get_enabled?(section) do
    case get_progress_scoring_settings(section) do
      {:ok, settings} -> settings.enabled
      _ -> false
    end
  end

  # Helper to convert string keys to atom keys for embedded schemas
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        try do
          {String.to_existing_atom(key), value}
        rescue
          ArgumentError -> {key, value}
        end

      {key, value} ->
        {key, value}
    end)
  end
end
