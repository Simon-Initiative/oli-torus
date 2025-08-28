defmodule Oli.ScopedFeatureFlags do
  @moduledoc """
  Context module for managing scoped feature flags.

  This module provides the public API for enabling/disabling feature flags
  that are scoped to either projects or sections, with mutual exclusion
  between the two resource types.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.ScopedFeatureFlags.ScopedFeatureFlagState

  @doc """
  Checks if a feature is enabled for a project or section.
  """
  def enabled?(feature_name, %Project{id: project_id}) do
    case get_feature_flag_state(feature_name, project_id: project_id) do
      %ScopedFeatureFlagState{enabled: enabled} -> enabled
      nil -> false
    end
  end

  def enabled?(feature_name, %Section{id: section_id}) do
    case get_feature_flag_state(feature_name, section_id: section_id) do
      %ScopedFeatureFlagState{enabled: enabled} -> enabled
      nil -> false
    end
  end

  @doc """
  Enables a feature for a project or section.
  """
  def enable_feature(feature_name, %Project{id: project_id}) do
    set_feature_flag(feature_name, project_id: project_id, enabled: true)
  end

  def enable_feature(feature_name, %Section{id: section_id}) do
    set_feature_flag(feature_name, section_id: section_id, enabled: true)
  end

  @doc """
  Disables a feature for a project or section.
  """
  def disable_feature(feature_name, %Project{id: project_id}) do
    set_feature_flag(feature_name, project_id: project_id, enabled: false)
  end

  def disable_feature(feature_name, %Section{id: section_id}) do
    set_feature_flag(feature_name, section_id: section_id, enabled: false)
  end

  @doc """
  Lists all feature flag states for a project.
  """
  def list_project_features(%Project{id: project_id}) do
    ScopedFeatureFlagState
    |> where(project_id: ^project_id)
    |> order_by(:feature_name)
    |> Repo.all()
  end

  @doc """
  Lists all feature flag states for a section.
  """
  def list_section_features(%Section{id: section_id}) do
    ScopedFeatureFlagState
    |> where(section_id: ^section_id)
    |> order_by(:feature_name)
    |> Repo.all()
  end

  @doc """
  Lists all feature flag states across all projects and sections.
  Useful for admin dashboard views.
  """
  def list_all_features do
    ScopedFeatureFlagState
    |> preload([:project, :section])
    |> order_by([:feature_name, :project_id, :section_id])
    |> Repo.all()
  end

  @doc """
  Batch lookup for checking if multiple features are enabled for a project or section.
  Returns a map of feature_name -> boolean.
  """
  def batch_enabled?(feature_names, %Project{id: project_id}) when is_list(feature_names) do
    enabled_features =
      ScopedFeatureFlagState
      |> where(feature_name: ^feature_names, project_id: ^project_id, enabled: true)
      |> select([:feature_name])
      |> Repo.all()
      |> Enum.map(& &1.feature_name)
      |> MapSet.new()

    Enum.into(feature_names, %{}, fn feature_name ->
      {feature_name, MapSet.member?(enabled_features, feature_name)}
    end)
  end

  def batch_enabled?(feature_names, %Section{id: section_id}) when is_list(feature_names) do
    enabled_features =
      ScopedFeatureFlagState
      |> where(feature_name: ^feature_names, section_id: ^section_id, enabled: true)
      |> select([:feature_name])
      |> Repo.all()
      |> Enum.map(& &1.feature_name)
      |> MapSet.new()

    Enum.into(feature_names, %{}, fn feature_name ->
      {feature_name, MapSet.member?(enabled_features, feature_name)}
    end)
  end

  @doc """
  Batch lookup for checking if a single feature is enabled across multiple projects.
  Returns a map of project_id -> boolean.
  """
  def batch_enabled_projects?(feature_name, project_ids) when is_list(project_ids) do
    enabled_projects =
      ScopedFeatureFlagState
      |> where(feature_name: ^feature_name, project_id: ^project_ids, enabled: true)
      |> select([:project_id])
      |> Repo.all()
      |> Enum.map(& &1.project_id)
      |> MapSet.new()

    Enum.into(project_ids, %{}, fn project_id ->
      {project_id, MapSet.member?(enabled_projects, project_id)}
    end)
  end

  @doc """
  Batch lookup for checking if a single feature is enabled across multiple sections.
  Returns a map of section_id -> boolean.
  """
  def batch_enabled_sections?(feature_name, section_ids) when is_list(section_ids) do
    enabled_sections =
      ScopedFeatureFlagState
      |> where(feature_name: ^feature_name, section_id: ^section_ids, enabled: true)
      |> select([:section_id])
      |> Repo.all()
      |> Enum.map(& &1.section_id)
      |> MapSet.new()

    Enum.into(section_ids, %{}, fn section_id ->
      {section_id, MapSet.member?(enabled_sections, section_id)}
    end)
  end

  @doc """
  Sets multiple features atomically for a project or section.
  All operations succeed or all fail.
  """
  def set_features_atomically(feature_settings, %Project{id: project_id}) do
    Repo.transaction(fn ->
      Enum.map(feature_settings, fn {feature_name, enabled} ->
        case set_feature_flag(feature_name, project_id: project_id, enabled: enabled) do
          {:ok, flag_state} -> flag_state
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end)
  end

  def set_features_atomically(feature_settings, %Section{id: section_id}) do
    Repo.transaction(fn ->
      Enum.map(feature_settings, fn {feature_name, enabled} ->
        case set_feature_flag(feature_name, section_id: section_id, enabled: enabled) do
          {:ok, flag_state} -> flag_state
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end)
  end

  @doc """
  Removes a feature flag state for a project or section.
  """
  def remove_feature(feature_name, %Project{id: project_id}) do
    case get_feature_flag_state(feature_name, project_id: project_id) do
      %ScopedFeatureFlagState{} = flag_state ->
        Repo.delete(flag_state)

      nil ->
        {:error, :not_found}
    end
  end

  def remove_feature(feature_name, %Section{id: section_id}) do
    case get_feature_flag_state(feature_name, section_id: section_id) do
      %ScopedFeatureFlagState{} = flag_state ->
        Repo.delete(flag_state)

      nil ->
        {:error, :not_found}
    end
  end

  # Private functions

  defp validate_feature_name(feature_name) do
    cond do
      not is_binary(feature_name) ->
        {:error, :invalid_feature_name, "Feature name must be a string"}

      String.length(feature_name) == 0 ->
        {:error, :invalid_feature_name, "Feature name cannot be empty"}

      String.length(feature_name) > 255 ->
        {:error, :invalid_feature_name, "Feature name cannot be longer than 255 characters"}

      not Regex.match?(~r/^[a-zA-Z0-9_\-.]+$/, feature_name) ->
        {:error, :invalid_feature_name, "Feature name can only contain letters, numbers, underscores, hyphens, and periods"}

      true ->
        :ok
    end
  end

  defp validate_resource_id(resource_id) when is_integer(resource_id) and resource_id > 0, do: :ok
  defp validate_resource_id(_), do: {:error, :invalid_resource_id, "Resource ID must be a positive integer"}

  defp get_feature_flag_state(feature_name, project_id: project_id) do
    ScopedFeatureFlagState
    |> where(feature_name: ^feature_name, project_id: ^project_id)
    |> Repo.one()
  end

  defp get_feature_flag_state(feature_name, section_id: section_id) do
    ScopedFeatureFlagState
    |> where(feature_name: ^feature_name, section_id: ^section_id)
    |> Repo.one()
  end

  defp set_feature_flag(feature_name, project_id: project_id, enabled: enabled) do
    with :ok <- validate_feature_name(feature_name),
         :ok <- validate_resource_id(project_id) do
      case get_feature_flag_state(feature_name, project_id: project_id) do
        %ScopedFeatureFlagState{} = existing ->
          existing
          |> ScopedFeatureFlagState.changeset(%{enabled: enabled})
          |> Repo.update()

        nil ->
          %ScopedFeatureFlagState{}
          |> ScopedFeatureFlagState.changeset_with_project(
            %{feature_name: feature_name, enabled: enabled},
            project_id
          )
          |> Repo.insert()
      end
    else
      {:error, type, message} -> {:error, %{type => [message]}}
    end
  end

  defp set_feature_flag(feature_name, section_id: section_id, enabled: enabled) do
    with :ok <- validate_feature_name(feature_name),
         :ok <- validate_resource_id(section_id) do
      case get_feature_flag_state(feature_name, section_id: section_id) do
        %ScopedFeatureFlagState{} = existing ->
          existing
          |> ScopedFeatureFlagState.changeset(%{enabled: enabled})
          |> Repo.update()

        nil ->
          %ScopedFeatureFlagState{}
          |> ScopedFeatureFlagState.changeset_with_section(
            %{feature_name: feature_name, enabled: enabled},
            section_id
          )
          |> Repo.insert()
      end
    else
      {:error, type, message} -> {:error, %{type => [message]}}
    end
  end
end