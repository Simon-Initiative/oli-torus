defmodule Oli.ScopedFeatureFlags do
  @moduledoc """
  Context module for managing scoped feature flags.

  This module provides the public API for enabling/disabling feature flags
  that are scoped to either projects or sections, with mutual exclusion
  between the two resource types.

  ## Feature Definition Patterns

  Features are defined centrally in `Oli.ScopedFeatureFlags.DefinedFeatures` using
  the `deffeature/3` macro from `Oli.ScopedFeatureFlags.Features`:

      deffeature :my_feature, [:authoring], "Description of the feature"
      deffeature :delivery_feature, [:delivery], "Feature for sections only"
      deffeature :universal_feature, [:both], "Feature for both contexts"

  ### Scope Rules

  - `:authoring` - Feature can only be used with projects
  - `:delivery` - Feature can only be used with sections  
  - `:both` - Feature can be used with both projects and sections
  - `[:authoring, :delivery]` - Equivalent to `:both`

  ### Compile-Time Validation

  When using literal atoms for feature names, this module performs compile-time
  validation to ensure the features are defined. Runtime validation is always
  performed for dynamic feature names.

  ### Usage Examples

      # Enable for a project (authoring context)
      ScopedFeatureFlags.enable_feature(:mcp_authoring, project)
      
      # Check if enabled
      if ScopedFeatureFlags.enabled?(:mcp_authoring, project) do
        # Feature is enabled
      end
      
      # Batch operations
      ScopedFeatureFlags.batch_enabled?([:feature1, :feature2], project)
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Auditing
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.ScopedFeatureFlags.ScopedFeatureFlagState
  alias Oli.ScopedFeatureFlags.DefinedFeatures

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Oli.ScopedFeatureFlags, only: [validate_feature_at_compile_time: 1]
    end
  end

  @doc false
  defmacro validate_feature_at_compile_time(feature_name) when is_atom(feature_name) do
    unless DefinedFeatures.valid_feature?(feature_name) do
      IO.warn(
        """
        Undefined feature flag: #{inspect(feature_name)}

        Available features:
        #{DefinedFeatures.feature_names() |> Enum.map(&"  - #{inspect(&1)}") |> Enum.join("\n")}

        Features must be defined in Oli.ScopedFeatureFlags.DefinedFeatures using the deffeature/3 macro.
        """,
        Macro.Env.stacktrace(__CALLER__)
      )
    end

    feature_name
  end

  defmacro validate_feature_at_compile_time(feature_name), do: feature_name

  @doc """
  Checks if a feature is enabled for a project or section.
  """
  def enabled?(feature_name, %Project{id: project_id}) do
    validate_feature_name_at_runtime(feature_name)

    feature_name_string =
      if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

    case get_feature_flag_state(feature_name_string, project_id: project_id) do
      %ScopedFeatureFlagState{} -> true
      nil -> false
    end
  end

  def enabled?(feature_name, %Section{id: section_id}) do
    validate_feature_name_at_runtime(feature_name)

    feature_name_string =
      if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

    case get_feature_flag_state(feature_name_string, section_id: section_id) do
      %ScopedFeatureFlagState{} -> true
      nil -> false
    end
  end

  @doc """
  Enables a feature for a project or section.

  ## Parameters
  - feature_name: The name of the feature to enable (atom or string)
  - resource: The project or section to enable the feature for
  - actor: (optional) The user or author performing the action for audit logging
  """
  def enable_feature(feature_name, resource, actor \\ nil)

  def enable_feature(feature_name, %Project{id: project_id} = project, actor) do
    validate_feature_name_at_runtime(feature_name)

    feature_name_string =
      if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

    case set_feature_flag(feature_name_string, project_id: project_id, enabled: true) do
      {:ok, flag_state} ->
        log_feature_flag_change(actor, :feature_flag_enabled, project, feature_name_string, true)
        {:ok, flag_state}

      error ->
        error
    end
  end

  def enable_feature(feature_name, %Section{id: section_id} = section, actor) do
    validate_feature_name_at_runtime(feature_name)

    feature_name_string =
      if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

    case set_feature_flag(feature_name_string, section_id: section_id, enabled: true) do
      {:ok, flag_state} ->
        log_feature_flag_change(actor, :feature_flag_enabled, section, feature_name_string, true)
        {:ok, flag_state}

      error ->
        error
    end
  end

  @doc """
  Disables a feature for a project or section.

  ## Parameters
  - feature_name: The name of the feature to disable (atom or string)
  - resource: The project or section to disable the feature for
  - actor: (optional) The user or author performing the action for audit logging
  """
  def disable_feature(feature_name, resource, actor \\ nil)

  def disable_feature(feature_name, %Project{id: project_id} = project, actor) do
    validate_feature_name_at_runtime(feature_name)

    feature_name_string =
      if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

    case set_feature_flag(feature_name_string, project_id: project_id, enabled: false) do
      {:ok, flag_state} ->
        log_feature_flag_change(
          actor,
          :feature_flag_disabled,
          project,
          feature_name_string,
          false
        )

        {:ok, flag_state}

      error ->
        error
    end
  end

  def disable_feature(feature_name, %Section{id: section_id} = section, actor) do
    validate_feature_name_at_runtime(feature_name)

    feature_name_string =
      if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

    case set_feature_flag(feature_name_string, section_id: section_id, enabled: false) do
      {:ok, flag_state} ->
        log_feature_flag_change(
          actor,
          :feature_flag_disabled,
          section,
          feature_name_string,
          false
        )

        {:ok, flag_state}

      error ->
        error
    end
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
      |> where([s], s.feature_name in ^feature_names and s.project_id == ^project_id)
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
      |> where([s], s.feature_name in ^feature_names and s.section_id == ^section_id)
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
      |> where([s], s.feature_name == ^feature_name and s.project_id in ^project_ids)
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
      |> where([s], s.feature_name == ^feature_name and s.section_id in ^section_ids)
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

  ## Parameters
  - feature_settings: List of {feature_name, enabled} tuples
  - resource: The project or section to set features for
  - actor: (optional) The user or author performing the action for audit logging
  """
  def set_features_atomically(feature_settings, resource, actor \\ nil)

  def set_features_atomically(feature_settings, %Project{id: project_id} = project, actor) do
    Repo.transaction(fn ->
      Enum.map(feature_settings, fn {feature_name, enabled} ->
        case set_feature_flag(feature_name, project_id: project_id, enabled: enabled) do
          {:ok, flag_state} ->
            # Log the individual feature change
            event_type = if enabled, do: :feature_flag_enabled, else: :feature_flag_disabled

            feature_name_string =
              if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

            log_feature_flag_change(actor, event_type, project, feature_name_string, enabled)
            flag_state

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end)
  end

  def set_features_atomically(feature_settings, %Section{id: section_id} = section, actor) do
    Repo.transaction(fn ->
      Enum.map(feature_settings, fn {feature_name, enabled} ->
        case set_feature_flag(feature_name, section_id: section_id, enabled: enabled) do
          {:ok, flag_state} ->
            # Log the individual feature change
            event_type = if enabled, do: :feature_flag_enabled, else: :feature_flag_disabled

            feature_name_string =
              if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

            log_feature_flag_change(actor, event_type, section, feature_name_string, enabled)
            flag_state

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end)
  end

  @doc """
  Returns all defined features with their metadata.
  """
  def all_defined_features do
    DefinedFeatures.all_features()
  end

  @doc """
  Returns all features that can be used in the authoring context (projects).
  """
  def authoring_features do
    DefinedFeatures.features_for_scope(:authoring)
  end

  @doc """
  Returns all features that can be used in the delivery context (sections).
  """
  def delivery_features do
    DefinedFeatures.features_for_scope(:delivery)
  end

  @doc """
  Checks if a feature name is valid (defined in the system).
  """
  def valid_feature?(feature_name) do
    DefinedFeatures.valid_feature?(feature_name)
  end

  @doc """
  Gets metadata for a specific feature.
  Returns nil if the feature is not defined.
  """
  def get_feature_metadata(feature_name) do
    DefinedFeatures.get_feature(feature_name)
  end

  @doc """
  Removes a feature flag state for a project or section.

  ## Parameters
  - feature_name: The name of the feature to remove (atom or string)
  - resource: The project or section to remove the feature from
  - actor: (optional) The user or author performing the action for audit logging
  """
  def remove_feature(feature_name, resource, actor \\ nil)

  def remove_feature(feature_name, %Project{id: project_id} = project, actor) do
    validate_feature_name_at_runtime(feature_name)

    feature_name_string =
      if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

    case get_feature_flag_state(feature_name_string, project_id: project_id) do
      %ScopedFeatureFlagState{} = flag_state ->
        case Repo.delete(flag_state) do
          {:ok, deleted_state} ->
            log_feature_flag_change(
              actor,
              :feature_flag_removed,
              project,
              feature_name_string,
              nil
            )

            {:ok, deleted_state}

          error ->
            error
        end

      nil ->
        {:error, :not_found}
    end
  end

  def remove_feature(feature_name, %Section{id: section_id} = section, actor) do
    validate_feature_name_at_runtime(feature_name)

    feature_name_string =
      if is_atom(feature_name), do: Atom.to_string(feature_name), else: feature_name

    case get_feature_flag_state(feature_name_string, section_id: section_id) do
      %ScopedFeatureFlagState{} = flag_state ->
        case Repo.delete(flag_state) do
          {:ok, deleted_state} ->
            log_feature_flag_change(
              actor,
              :feature_flag_removed,
              section,
              feature_name_string,
              nil
            )

            {:ok, deleted_state}

          error ->
            error
        end

      nil ->
        {:error, :not_found}
    end
  end

  # Private functions

  defp log_feature_flag_change(actor, event_type, resource, feature_name, enabled_value) do
    details = %{
      "feature_name" => feature_name,
      "enabled" => enabled_value
    }

    {details, resource} =
      case resource do
        %Project{} = project ->
          details = Map.put(details, "resource_type", "project")

          details =
            if project.title, do: Map.put(details, "project_title", project.title), else: details

          {details, project}

        %Section{} = section ->
          details = Map.put(details, "resource_type", "section")

          details =
            if section.title, do: Map.put(details, "section_title", section.title), else: details

          {details, section}

        _ ->
          {details, resource}
      end

    # Only log if we have an actor (user or author)
    if actor do
      case Auditing.capture(actor, event_type, resource, details) do
        {:ok, _event} -> :ok
        # Don't fail the main operation if audit logging fails
        {:error, _changeset} -> :ok
      end
    end
  end

  defp validate_feature_name_at_runtime(feature_name) when is_atom(feature_name) do
    unless DefinedFeatures.valid_feature?(feature_name) do
      raise ArgumentError, """
      Undefined feature flag: #{inspect(feature_name)}

      Available features: #{DefinedFeatures.feature_names() |> Enum.map(&inspect/1) |> Enum.join(", ")}

      Features must be defined in Oli.ScopedFeatureFlags.DefinedFeatures using the deffeature/3 macro.
      """
    end
  end

  defp validate_feature_name_at_runtime(feature_name) when is_binary(feature_name) do
    unless DefinedFeatures.valid_feature?(feature_name) do
      raise ArgumentError, """
      Undefined feature flag: #{inspect(feature_name)}

      Available features: #{DefinedFeatures.feature_strings() |> Enum.join(", ")}

      Features must be defined in Oli.ScopedFeatureFlags.DefinedFeatures using the deffeature/3 macro.
      """
    end
  end

  defp validate_feature_name_at_runtime(_feature_name) do
    raise ArgumentError, "Feature name must be an atom or string"
  end

  defp validate_feature_name(feature_name) do
    cond do
      not is_binary(feature_name) ->
        {:error, :invalid_feature_name, "Feature name must be a string"}

      String.length(feature_name) == 0 ->
        {:error, :invalid_feature_name, "Feature name cannot be empty"}

      String.length(feature_name) > 255 ->
        {:error, :invalid_feature_name, "Feature name cannot be longer than 255 characters"}

      not Regex.match?(~r/^[a-zA-Z0-9_\-.]+$/, feature_name) ->
        {:error, :invalid_feature_name,
         "Feature name can only contain letters, numbers, underscores, hyphens, and periods"}

      not DefinedFeatures.valid_feature?(feature_name) ->
        {:error, :invalid_feature_name,
         "Feature '#{feature_name}' is not defined. Available features: #{DefinedFeatures.feature_strings() |> Enum.join(", ")}"}

      true ->
        :ok
    end
  end

  defp validate_feature_scope(feature_name, scope)
       when is_binary(feature_name) and is_atom(scope) do
    if DefinedFeatures.feature_supports_scope?(feature_name, scope) do
      :ok
    else
      feature = DefinedFeatures.get_feature(feature_name)
      supported_scopes = if feature, do: feature.scopes, else: []

      {:error, :invalid_scope,
       "Feature '#{feature_name}' does not support scope '#{scope}'. Supported scopes: #{inspect(supported_scopes)}"}
    end
  end

  defp validate_resource_id(resource_id) when is_integer(resource_id) and resource_id > 0, do: :ok

  defp validate_resource_id(_),
    do: {:error, :invalid_resource_id, "Resource ID must be a positive integer"}

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

  defp set_feature_flag(feature_name, project_id: project_id, enabled: true) do
    with :ok <- validate_feature_name(feature_name),
         :ok <- validate_feature_scope(feature_name, :authoring),
         :ok <- validate_resource_id(project_id) do
      case get_feature_flag_state(feature_name, project_id: project_id) do
        %ScopedFeatureFlagState{} = existing ->
          # Already enabled, return the existing record
          {:ok, existing}

        nil ->
          # Create new record to enable feature
          %ScopedFeatureFlagState{}
          |> ScopedFeatureFlagState.changeset_with_project(
            %{feature_name: feature_name},
            project_id
          )
          |> Repo.insert()
      end
    else
      {:error, type, message} -> {:error, %{type => [message]}}
    end
  end

  defp set_feature_flag(feature_name, project_id: project_id, enabled: false) do
    with :ok <- validate_feature_name(feature_name),
         :ok <- validate_feature_scope(feature_name, :authoring),
         :ok <- validate_resource_id(project_id) do
      case get_feature_flag_state(feature_name, project_id: project_id) do
        %ScopedFeatureFlagState{} = existing ->
          # Delete the record to disable feature
          Repo.delete(existing)

        nil ->
          # Already disabled, return ok
          {:ok, nil}
      end
    else
      {:error, type, message} -> {:error, %{type => [message]}}
    end
  end

  defp set_feature_flag(feature_name, section_id: section_id, enabled: true) do
    with :ok <- validate_feature_name(feature_name),
         :ok <- validate_feature_scope(feature_name, :delivery),
         :ok <- validate_resource_id(section_id) do
      case get_feature_flag_state(feature_name, section_id: section_id) do
        %ScopedFeatureFlagState{} = existing ->
          # Already enabled, return the existing record
          {:ok, existing}

        nil ->
          # Create new record to enable feature
          %ScopedFeatureFlagState{}
          |> ScopedFeatureFlagState.changeset_with_section(
            %{feature_name: feature_name},
            section_id
          )
          |> Repo.insert()
      end
    else
      {:error, type, message} -> {:error, %{type => [message]}}
    end
  end

  defp set_feature_flag(feature_name, section_id: section_id, enabled: false) do
    with :ok <- validate_feature_name(feature_name),
         :ok <- validate_feature_scope(feature_name, :delivery),
         :ok <- validate_resource_id(section_id) do
      case get_feature_flag_state(feature_name, section_id: section_id) do
        %ScopedFeatureFlagState{} = existing ->
          # Delete the record to disable feature
          Repo.delete(existing)

        nil ->
          # Already disabled, return ok
          {:ok, nil}
      end
    else
      {:error, type, message} -> {:error, %{type => [message]}}
    end
  end
end
