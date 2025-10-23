defmodule Oli.ScopedFeatureFlags.Features do
  @moduledoc """
  Compile-time feature definition system for scoped feature flags.

  This module provides macros and functions for defining feature flags at compile time,
  ensuring that only valid, predefined features can be used throughout the system.

  ## Usage

  Feature flags are defined using the `deffeature/3` macro:

      defmodule MyApp.Features do
        use Oli.ScopedFeatureFlags.Features

        deffeature :my_feature, [:authoring, :delivery], "Description of my feature"
        deffeature :another_feature, [:both], "Another feature description"
      end

  ## Scopes

  Each feature must specify which scopes it supports:
  - `:authoring` - Feature can be scoped to projects (authoring context)
  - `:delivery` - Feature can be scoped to sections (delivery context)
  - `:both` - Feature can be scoped to both projects and sections

  ## Validation

  Feature names are validated at compile time and runtime to ensure:
  - Only defined features can be used
  - Features are used with appropriate scopes
  - All feature metadata is accessible for UI generation
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Oli.ScopedFeatureFlags.Features, only: [deffeature: 3]

      @before_compile Oli.ScopedFeatureFlags.Features
      @features []
    end
  end

  @doc """
  Defines a feature flag with metadata.

  ## Parameters
  - `name` - Atom representing the feature name (e.g., `:mcp_authoring`)
  - `scopes` - List of scopes where the feature can be used (`:authoring`, `:delivery`, or `:both`)
  - `description` - Human-readable description of the feature

  ## Examples

      deffeature :mcp_authoring, [:authoring], "Enable MCP authoring capabilities"
      deffeature :advanced_analytics, [:both], "Advanced analytics dashboard"
      deffeature :auto_grading, [:delivery], "Automatic grading system"
  """
  defmacro deffeature(name, scopes, description) do
    quote do
      @features [{unquote(name), unquote(scopes), unquote(description)} | @features]
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    features = Module.get_attribute(env.module, :features) |> Enum.reverse()

    # Validate features at compile time
    validate_features!(features)

    # Pre-compute the lists for efficiency
    feature_names = Enum.map(features, fn {name, _scopes, _description} -> name end)

    feature_strings =
      Enum.map(features, fn {name, _scopes, _description} -> Atom.to_string(name) end)

    quote do
      @doc """
      Returns all defined features with their metadata.
      """
      def all_features do
        unquote(Macro.escape(features))
        |> Enum.map(fn {name, scopes, description} ->
          %{
            name: name,
            scopes: scopes,
            description: description,
            string_name: Atom.to_string(name)
          }
        end)
      end

      @doc """
      Returns a list of all feature names as atoms.
      """
      def feature_names do
        unquote(feature_names)
      end

      @doc """
      Returns a list of all feature names as strings.
      """
      def feature_strings do
        unquote(feature_strings)
      end

      @doc """
      Checks if a feature name is valid (defined).
      """
      def valid_feature?(feature_name) when is_atom(feature_name) do
        feature_name in unquote(feature_names)
      end

      def valid_feature?(feature_name) when is_binary(feature_name) do
        feature_name in unquote(feature_strings)
      end

      @doc """
      Gets the metadata for a specific feature.
      Returns nil if the feature is not defined.
      """
      def get_feature(feature_name) when is_atom(feature_name) do
        case Enum.find(unquote(Macro.escape(features)), fn {name, _scopes, _description} ->
               name == feature_name
             end) do
          {name, scopes, description} ->
            %{
              name: name,
              scopes: scopes,
              description: description,
              string_name: Atom.to_string(name)
            }

          nil ->
            nil
        end
      end

      def get_feature(feature_name) when is_binary(feature_name) do
        get_feature(String.to_existing_atom(feature_name))
      rescue
        ArgumentError -> nil
      end

      @doc """
      Checks if a feature supports a specific scope.
      """
      def feature_supports_scope?(feature_name, scope)
          when is_atom(feature_name) and is_atom(scope) do
        case get_feature(feature_name) do
          %{scopes: scopes} -> scope in scopes or :both in scopes
          nil -> false
        end
      end

      def feature_supports_scope?(feature_name, scope)
          when is_binary(feature_name) and is_atom(scope) do
        feature_supports_scope?(String.to_existing_atom(feature_name), scope)
      rescue
        ArgumentError -> false
      end

      @doc """
      Returns all features that support a specific scope.
      """
      def features_for_scope(scope) when is_atom(scope) do
        unquote(Macro.escape(features))
        |> Enum.filter(fn {_name, scopes, _description} ->
          scope in scopes or :both in scopes
        end)
        |> Enum.map(fn {name, scopes, description} ->
          %{
            name: name,
            scopes: scopes,
            description: description,
            string_name: Atom.to_string(name)
          }
        end)
      end
    end
  end

  @doc false
  def validate_features!(features) do
    # Check for duplicate feature names
    names = Enum.map(features, fn {name, _scopes, _description} -> name end)
    duplicates = names -- Enum.uniq(names)

    if duplicates != [] do
      raise CompileError,
        description: "Duplicate feature names found: #{inspect(Enum.uniq(duplicates))}"
    end

    # Validate each feature
    Enum.each(features, fn {name, scopes, description} ->
      validate_feature_name!(name)
      validate_scopes!(scopes)
      validate_description!(description)
    end)
  end

  @doc false
  def validate_feature_name!(name) do
    unless is_atom(name) do
      raise CompileError, description: "Feature name must be an atom, got: #{inspect(name)}"
    end

    name_str = Atom.to_string(name)

    if String.length(name_str) == 0 do
      raise CompileError, description: "Feature name cannot be empty"
    end

    if String.length(name_str) > 255 do
      raise CompileError,
        description: "Feature name cannot be longer than 255 characters: #{inspect(name)}"
    end

    unless Regex.match?(~r/^[a-zA-Z0-9_\-.]+$/, name_str) do
      raise CompileError,
        description:
          "Feature name can only contain letters, numbers, underscores, hyphens, and periods: #{inspect(name)}"
    end

    :ok
  end

  @doc false
  def validate_scopes!(scopes) do
    unless is_list(scopes) and scopes != [] do
      raise CompileError, description: "Scopes must be a non-empty list, got: #{inspect(scopes)}"
    end

    valid_scopes = [:authoring, :delivery, :both]

    Enum.each(scopes, fn scope ->
      unless scope in valid_scopes do
        raise CompileError,
          description:
            "Invalid scope: #{inspect(scope)}. Valid scopes are: #{inspect(valid_scopes)}"
      end
    end)

    # Check for conflicting scopes
    if :both in scopes and length(scopes) > 1 do
      raise CompileError,
        description: "Cannot use :both scope with other scopes: #{inspect(scopes)}"
    end

    :ok
  end

  @doc false
  def validate_description!(description) do
    unless is_binary(description) do
      raise CompileError,
        description: "Description must be a string, got: #{inspect(description)}"
    end

    if String.length(description) == 0 do
      raise CompileError, description: "Description cannot be empty"
    end

    if String.length(description) > 500 do
      raise CompileError, description: "Description cannot be longer than 500 characters"
    end

    :ok
  end
end
