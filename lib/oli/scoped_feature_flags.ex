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
  end

  defp set_feature_flag(feature_name, section_id: section_id, enabled: enabled) do
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
  end
end