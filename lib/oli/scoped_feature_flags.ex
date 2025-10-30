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

  require Logger

  alias Oli.Repo
  alias Oli.Auditing
  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.ScopedFeatureFlags.ScopedFeatureFlagState
  alias Oli.ScopedFeatureFlags.DefinedFeatures
  alias Oli.ScopedFeatureFlags.{Rollouts, ScopedFeatureRollout, ScopedFeatureExemption}

  @stage_cache :feature_flag_stage
  @cohort_cache :feature_flag_cohorts
  @cohort_hash_version 1
  @decision_event [:torus, :feature_flag, :decision]

  @hash_space_max :binary.decode_unsigned(:binary.copy(<<255>>, 32))

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

  @doc """
  Determines whether an actor can access a feature within the provided scope resource.

  When `opts[:diagnostics]` is true, returns `{:ok, diagnostics_map}` or `{:error, reason}`.
  Diagnostics include the resolved stage, cache hit metadata, and exemption details.

  Options:
    * `:diagnostics` - when true, returns diagnostic details instead of boolean.
    * `:bypass_cache` - when true, skips Cachex for stage/cohort evaluation.
  """
  def can_access?(feature_name, actor, resource, opts \\ [])

  def can_access?(feature_name, actor, resource, opts) do
    diagnostics? = Keyword.get(opts, :diagnostics, false)

    case evaluate_access(feature_name, actor, resource, opts) do
      {:ok, diagnostics} ->
        if diagnostics?, do: {:ok, diagnostics}, else: diagnostics.result

      {:error, reason} ->
        if diagnostics?, do: {:error, reason}, else: false
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

  defp evaluate_access(feature_name, actor, resource, opts) do
    validate_feature_name_at_runtime(feature_name)

    feature_metadata =
      case DefinedFeatures.get_feature(feature_name) do
        nil ->
          {:error, :undefined_feature}

        metadata ->
          {:ok, metadata}
      end

    with {:ok, metadata} <- feature_metadata,
         {:ok, scope} <- derive_scope(resource),
         {:ok, actor_info} <- normalize_actor(actor),
         {:ok, diagnostics} <-
           do_evaluate_access(metadata, actor_info, scope, opts) do
      {:ok, diagnostics}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_evaluate_access(
         %{name: feature_name, metadata: metadata},
         actor_info,
         scope,
         opts
       ) do
    bypass_cache? = Keyword.get(opts, :bypass_cache, false)

    result =
      case Map.get(metadata, :rollout_mode, :scoped_only) do
        :scoped_only ->
          evaluate_scoped_only(feature_name, scope, actor_info, bypass_cache?)

        :canary ->
          evaluate_canary(feature_name, scope, actor_info, bypass_cache?)
      end

    case result do
      {:ok, diagnostics} ->
        telemetry_decision(diagnostics)
        {:ok, diagnostics}

      {:error, _reason, diagnostics} ->
        telemetry_decision(diagnostics)
        {:ok, diagnostics}

      {:error, reason} ->
        telemetry_decision(%{
          feature: feature_name,
          result: false,
          reason: reason,
          actor: actor_summary(actor_info),
          scope: scope_summary(scope),
          cache_hits: %{}
        })

        {:error, reason}
    end
  end

  defp evaluate_scoped_only(feature_name, scope, actor_info, _bypass_cache?) do
    enabled =
      case scope.resource do
        %Project{} = project -> enabled?(feature_name, project)
        %Section{} = section -> enabled?(feature_name, section)
      end

    diagnostics = %{
      feature: normalize_feature_name(feature_name),
      result: enabled,
      mode: :scoped_only,
      stage: :full,
      stage_source: %{scope_type: scope.scope_type, scope_id: scope.scope_id},
      reason: if(enabled, do: :enabled, else: :scope_disabled),
      actor: actor_summary(actor_info),
      scope: scope_summary(scope),
      cache_hits: %{},
      hash_version: nil,
      exemption: nil
    }

    {:ok, diagnostics}
  end

  defp evaluate_canary(feature_name, scope, actor_info, bypass_cache?) do
    feature_string = normalize_feature_name(feature_name)

    evaluate_canary_enabled(feature_string, scope, actor_info, bypass_cache?)
  end

  defp evaluate_canary_enabled(feature_name, scope, actor_info, bypass_cache?) do
    start_time = System.monotonic_time()

    with {:ok, stage_info} <-
           resolve_stage(feature_name, scope, bypass_cache?),
         {:ok, exemption_info} <-
           resolve_exemption(feature_name, scope, bypass_cache?) do
      decision =
        decide_canary(
          feature_name,
          scope,
          actor_info,
          stage_info,
          exemption_info,
          bypass_cache?
        )

      duration = System.monotonic_time() - start_time

      case decision do
        {:ok, diagnostics} ->
          {:ok, Map.put(diagnostics, :duration, duration)}

        {:error, reason, diagnostics} ->
          {:error, reason, Map.put(diagnostics, :duration, duration)}
      end
    else
      {:error, reason} ->
        {:error, reason,
         %{
           feature: feature_name,
           result: false,
           reason: reason,
           mode: :canary,
           actor: actor_summary(actor_info),
           scope: scope_summary(scope),
           cache_hits: %{},
           hash_version: @cohort_hash_version,
           stage: :off,
           stage_source: %{scope_type: nil, scope_id: nil},
           exemption: nil
         }}
    end
  end

  defp decide_canary(
         feature_name,
         scope,
         actor_info,
         %{stage: stage} = stage_info,
         exemption_info,
         bypass_cache?
       ) do
    {result, reason, cache_hits, hash_hit} =
      case {stage, exemption_info} do
        {:off, %{effect: :force_enable}} ->
          {false, :stage_off, merge_cache_hits(stage_info, exemption_info), nil}

        {:off, %{effect: :deny}} ->
          {false, :publisher_denied, merge_cache_hits(stage_info, exemption_info), nil}

        {:off, nil} ->
          {false, :stage_off, merge_cache_hits(stage_info, exemption_info), nil}

        {_stage, %{effect: :deny}} ->
          {false, :publisher_denied, merge_cache_hits(stage_info, exemption_info), nil}

        {_stage, %{effect: :force_enable} = exemption} ->
          {true, :publisher_force_enable, merge_cache_hits(stage_info, exemption), nil}

        {:internal_only, _} ->
          if actor_info.internal? do
            {true, :internal, merge_cache_hits(stage_info, exemption_info), nil}
          else
            {false, :not_internal, merge_cache_hits(stage_info, exemption_info), nil}
          end

        {stage, _} when stage in [:five_percent, :fifty_percent] ->
          if actor_info.internal? do
            {true, :internal, merge_cache_hits(stage_info, exemption_info), nil}
          else
            case cohort_allows?(feature_name, actor_info, stage, bypass_cache?) do
              {:ok, %{result: true} = cohort_diag} ->
                {true, :cohort_allow,
                 merge_cache_hits(stage_info, exemption_info, cohort_diag.cache_hits), cohort_diag}

              {:ok, %{result: false} = cohort_diag} ->
                {false, :cohort_deny,
                 merge_cache_hits(stage_info, exemption_info, cohort_diag.cache_hits), cohort_diag}

              {:error, reason} ->
                {false, reason, merge_cache_hits(stage_info, exemption_info), nil}
            end
          end

        {:full, _} ->
          {true, :stage_full, merge_cache_hits(stage_info, exemption_info), nil}
      end

    diagnostics =
      %{
        feature: feature_name,
        result: result,
        reason: reason,
        mode: :canary,
        stage: stage,
        stage_source: %{
          scope_type: stage_info.scope_type,
          scope_id: stage_info.scope_id
        },
        rollout_percentage: stage_info.rollout_percentage,
        actor: actor_summary(actor_info),
        scope: scope_summary(scope),
        exemption: exemption_summary(exemption_info),
        cache_hits: cache_hits,
        hash_version: @cohort_hash_version,
        hash_diagnostics: hash_hit
      }
      |> maybe_put(:publisher_id, scope.publisher_id)

    if result do
      {:ok, diagnostics}
    else
      {:error, reason, diagnostics}
    end
  end

  defp merge_cache_hits(stage_info, exemption_info, extra \\ %{}) do
    stage_hits = Map.get(stage_info, :cache_hits, %{})
    exemption_hits =
      exemption_info
      |> case do
        nil -> %{}
        info -> Map.get(info, :cache_hits, %{})
      end

    stage_hits
    |> Map.merge(exemption_hits)
    |> Map.merge(extra)
  end

  defp resolve_stage(feature_name, scope, bypass_cache?) do
    candidates = stage_candidates(scope)

    candidates
    |> Enum.reduce_while({:ok, nil}, fn {scope_type, scope_id}, {:ok, _} = acc ->
      case fetch_stage(feature_name, scope_type, scope_id, bypass_cache?) do
        {:ok, %{stage: stage} = info} when not is_nil(stage) ->
          {:halt,
           {:ok,
            Map.merge(info, %{
              scope_type: scope_type,
              scope_id: scope_id,
              cache_hits: %{stage: info.cache_source}
            })}}

        {:ok, nil} ->
          {:cont, acc}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, nil} ->
        {:ok,
         %{
           stage: :off,
           scope_type: :global,
           scope_id: nil,
           rollout_percentage: 0,
           cache_hits: %{stage: :miss},
           cache_source: :miss
         }}

      {:ok, info} ->
        {:ok, Map.put_new(info, :rollout_percentage, percentage_for_stage(info.stage))}

      other ->
        other
    end
  end

  defp resolve_exemption(_feature_name, %{publisher_id: nil}, _bypass_cache?), do: {:ok, nil}

  defp resolve_exemption(feature_name, %{publisher_id: publisher_id}, bypass_cache?) do
    case fetch_exemption(feature_name, publisher_id, bypass_cache?) do
      {:ok, exemption_info} ->
        {:ok, exemption_info}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_stage(feature_name, scope_type, scope_id, bypass_cache?) do
    key = {:stage, feature_name, scope_type, scope_id}

    case cache_lookup(@stage_cache, key, bypass_cache?) do
      {:hit, value} ->
        {:ok, Map.put(value, :cache_source, :hit)}

      {:miss, _} ->
        case Rollouts.get_rollout(feature_name, scope_type, scope_id) do
          %ScopedFeatureRollout{} = rollout ->
            entry = %{
              stage: rollout.stage,
              scope_type: scope_type,
              scope_id: scope_id,
              rollout_percentage: rollout.rollout_percentage,
              cache_source: :populate
            }

            cache_store(@stage_cache, key, entry, [ttl: stage_cache_ttl()], bypass_cache?)
            {:ok, entry}

          nil ->
            cache_store(@stage_cache, key, nil, [ttl: stage_cache_ttl()], bypass_cache?)
            {:ok, nil}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_exemption(feature_name, publisher_id, bypass_cache?) do
    key = {:exemption, feature_name, publisher_id}

    case cache_lookup(@stage_cache, key, bypass_cache?) do
      {:hit, value} ->
        {:ok, value |> Map.put(:cache_hits, %{exemption: :hit})}

      {:miss, _} ->
        case Rollouts.get_exemption(feature_name, publisher_id) do
          %ScopedFeatureExemption{} = exemption ->
            entry = %{
              effect: exemption.effect,
              note: exemption.note,
              publisher_id: exemption.publisher_id,
              cache_hits: %{exemption: :populate}
            }

            cache_store(@stage_cache, key, entry, [ttl: stage_cache_ttl()], bypass_cache?)
            {:ok, entry}

          nil ->
            cache_store(@stage_cache, key, nil, [ttl: stage_cache_ttl()], bypass_cache?)
            {:ok, nil}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cohort_allows?(feature_name, actor_info, stage, bypass_cache?) do
    key = {:cohort, feature_name, actor_info.type, actor_info.id}

    stage_label = stage

    case cache_lookup(@cohort_cache, key, bypass_cache?) do
      {:hit, %{stage: cached_stage, result: result} = value}
      when cached_stage == stage_label and value.hash_version == @cohort_hash_version ->
        {:ok,
         %{
           result: result,
           cache_hits: %{cohort: :hit},
           hash_value: Map.get(value, :hash_value),
           stage: stage_label
         }}

      {:hit, _} ->
        compute_and_store_cohort(feature_name, actor_info, stage_label, key, bypass_cache?)

      {:miss, _} ->
        compute_and_store_cohort(feature_name, actor_info, stage_label, key, bypass_cache?)

      {:error, reason} ->
        Logger.warning("Cohort cache error: #{inspect(reason)}")
        {:error, :cohort_cache_error}
    end
  end

  defp compute_and_store_cohort(feature_name, actor_info, stage, key, bypass_cache?) do
    case hash_actor(feature_name, actor_info) do
      {:ok, hash_value} ->
        threshold = stage_threshold(stage)
        result = hash_value < threshold

        entry = %{
          result: result,
          hash_value: hash_value,
          stage: stage,
          hash_version: @cohort_hash_version
        }

        cache_store(@cohort_cache, key, entry, [ttl: cohort_cache_ttl()], bypass_cache?)

        {:ok,
         %{
           result: result,
           cache_hits: %{cohort: :populate},
           hash_value: hash_value,
           stage: stage
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hash_actor(_feature_name, %{id: nil}), do: {:error, :missing_actor_id}

  defp hash_actor(feature_name, %{type: type, id: id}) do
    data = "#{feature_name}:#{type}:#{id}:#{@cohort_hash_version}"

    hash =
      :crypto.hash(:sha256, data)

    {:ok, :binary.decode_unsigned(hash)}
  end

  defp stage_threshold(:five_percent), do: div(@hash_space_max * 5, 100)
  defp stage_threshold(:fifty_percent), do: div(@hash_space_max * 50, 100)
  defp stage_threshold(_stage), do: @hash_space_max

  defp normalize_actor(%Author{id: id} = author) do
    {:ok,
     %{
       id: id,
       type: :author,
       internal?: Map.get(author, :is_internal, false) || false,
       struct: author
     }}
  end

  defp normalize_actor(%User{id: id} = user) do
    {:ok,
     %{
       id: id,
       type: :user,
       internal?: Map.get(user, :is_internal, false) || false,
       struct: user
     }}
  end

  defp normalize_actor(nil), do: {:error, :missing_actor}

  defp normalize_actor(%{} = actor) do
    cond do
      Map.has_key?(actor, :id) ->
        {:ok,
         %{
           id: Map.get(actor, :id),
           type: Map.get(actor, :type, :unknown),
           internal?: Map.get(actor, :is_internal, false) || false,
           struct: actor
         }}

      true ->
        {:error, :unsupported_actor}
    end
  end

  defp derive_scope(%Project{} = project) do
    {:ok,
     %{
       resource: project,
       scope_type: :project,
       scope_id: project.id,
       publisher_id: ensure_project_publisher_id(project),
       project_id: project.id,
       section_id: nil
     }}
  end

  defp derive_scope(%Section{} = section) do
    publisher_id = ensure_section_publisher_id(section)

    {:ok,
     %{
       resource: section,
       scope_type: :section,
       scope_id: section.id,
       publisher_id: publisher_id,
       project_id: section.base_project_id,
       section_id: section.id
     }}
  end

  defp derive_scope(_), do: {:error, :unsupported_scope}

  defp ensure_project_publisher_id(%Project{publisher_id: publisher_id}) when not is_nil(publisher_id),
    do: publisher_id

  defp ensure_project_publisher_id(%Project{id: id}) do
    Repo.get!(Project, id).publisher_id
  end

  defp ensure_section_publisher_id(%Section{publisher_id: publisher_id}) when not is_nil(publisher_id),
    do: publisher_id

  defp ensure_section_publisher_id(%Section{id: id}) do
    Repo.get!(Section, id).publisher_id
  end

  defp stage_candidates(%{resource: %Project{id: project_id}}) do
    [
      {:project, project_id},
      {:global, nil}
    ]
  end

  defp stage_candidates(%{resource: %Section{id: section_id}, project_id: project_id}) do
    [
      {:project, project_id},
      {:section, section_id},
      {:global, nil}
    ]
    |> Enum.reject(fn
      {:project, nil} -> true
      {:section, nil} -> true
      _ -> false
    end)
  end

  defp percentage_for_stage(:five_percent), do: 5
  defp percentage_for_stage(:fifty_percent), do: 50
  defp percentage_for_stage(:full), do: 100
  defp percentage_for_stage(_), do: 0

  defp cache_lookup(_cache, _key, true), do: {:miss, nil}

  defp cache_lookup(cache, key, false) do
    case Cachex.get(cache, key) do
      {:ok, nil} -> {:miss, nil}
      {:ok, value} -> {:hit, value}
      {:error, :no_cache} -> {:miss, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cache_store(_cache, _key, _value, _opts, true), do: :ok

  defp cache_store(cache, key, value, opts, false) do
    case Cachex.put(cache, key, value, opts) do
      {:ok, true} -> :ok
      {:error, :no_cache} -> :ok
      {:error, reason} -> Logger.warning("Cache store failed: #{inspect(reason)}")
    end
  end

  @doc false
  def handle_pubsub_message({:stage_invalidated, feature_name, scope_type, scope_id}) do
    Cachex.del(@stage_cache, {:stage, feature_name, scope_type, scope_id})
    :ok
  end

  def handle_pubsub_message({:exemption_invalidated, feature_name, publisher_id}) do
    Cachex.del(@stage_cache, {:exemption, feature_name, publisher_id})
    :ok
  end

  def handle_pubsub_message({:cohort_flush, feature_name}) do
    flush_cohort_cache(feature_name)
    :ok
  end

  def handle_pubsub_message(_), do: :ok

  defp flush_cohort_cache(feature_name) do
    with {:ok, keys} <- Cachex.keys(@cohort_cache) do
      keys
      |> Enum.filter(fn key -> match?({:cohort, ^feature_name, _, _}, key) end)
      |> Enum.each(&Cachex.del(@cohort_cache, &1))
    else
      {:error, :no_cache} -> :ok
      {:error, reason} -> Logger.warning("Failed to stream cohort cache: #{inspect(reason)}")
    end
  end

  defp stage_cache_ttl, do: :timer.minutes(5)
  defp cohort_cache_ttl, do: :timer.minutes(30)

  defp normalize_feature_name(feature) when is_atom(feature), do: Atom.to_string(feature)
  defp normalize_feature_name(feature) when is_binary(feature), do: feature

  defp actor_summary(actor_info) do
    %{
      type: actor_info.type,
      id: actor_info.id,
      internal?: actor_info.internal?
    }
  end

  defp scope_summary(%{scope_type: scope_type, scope_id: scope_id, publisher_id: publisher_id}) do
    %{
      scope_type: scope_type,
      scope_id: scope_id,
      publisher_id: publisher_id
    }
  end

  defp exemption_summary(nil), do: nil
  defp exemption_summary(%{effect: effect, note: note}), do: %{effect: effect, note: note}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp telemetry_decision(%{duration: duration} = diagnostics) do
    measurements = %{duration: duration}

    metadata =
      diagnostics
      |> Map.drop([:duration])

    :telemetry.execute(@decision_event, measurements, metadata)
  end

  defp telemetry_decision(diagnostics) do
    :telemetry.execute(@decision_event, %{duration: 0}, diagnostics)
  end
end
