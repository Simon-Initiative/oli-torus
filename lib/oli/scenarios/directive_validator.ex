defmodule Oli.Scenarios.DirectiveValidator do
  @moduledoc """
  Validates directive attributes to ensure no unknown attributes are present.
  This helps catch typos and incorrect attribute usage in scenario YAML files.
  """

  @doc """
  Validates that only allowed attributes are present in the given data.

  ## Parameters
    - allowed_attrs: List of allowed attribute names (as strings)
    - data: Map of provided attributes from YAML
    - directive_name: Name of the directive for error reporting

  ## Returns
    - :ok if all attributes are valid
    - {:error, message} if unknown attributes are found
  """
  def validate_attributes(allowed_attrs, data, directive_name)
      when is_list(allowed_attrs) and is_map(data) and is_binary(directive_name) do
    provided_attrs = Map.keys(data)
    unknown_attrs = provided_attrs -- allowed_attrs

    case unknown_attrs do
      [] ->
        :ok

      unknown ->
        # Sort for consistent error messages
        unknown_sorted = Enum.sort(unknown)
        allowed_sorted = Enum.sort(allowed_attrs)

        {:error,
         "Unknown attributes in '#{directive_name}' directive: #{inspect(unknown_sorted)}. " <>
           "Allowed attributes are: #{inspect(allowed_sorted)}"}
    end
  end

  @doc """
  Validates attributes for nested structures like nodes in project trees.
  Similar to validate_attributes but for nested data structures.
  """
  def validate_node_attributes(data) when is_map(data) do
    cond do
      Map.has_key?(data, "page") ->
        # Page nodes should only have "page" key
        validate_attributes(["page"], data, "page node")

      Map.has_key?(data, "container") ->
        # Container nodes can have "container" and optionally "children"
        validate_attributes(["container", "children"], data, "container node")

      Map.has_key?(data, "root") ->
        # Root wrapper
        :ok

      Map.has_key?(data, "children") ->
        # Just children without container name (treated as root)
        validate_attributes(["children"], data, "root node")

      true ->
        {:error, "Invalid node structure. Expected 'page', 'container', or 'children' key."}
    end
  end

  @doc """
  Validates assertion sub-structures.
  """
  def validate_assertion_attributes(type, data) when is_map(data) do
    allowed_attrs =
      case type do
        :structure ->
          ["to", "root"]

        :resource ->
          ["to", "target", "resource"]

        :progress ->
          ["section", "progress", "page", "container", "student"]

        :proficiency ->
          ["section", "objective", "bucket", "value", "student", "page", "container"]

        _ ->
          []
      end

    validate_attributes(allowed_attrs, data, "#{type} assertion")
  end

  @doc """
  Validates objective format.
  Objectives can be either:
  - A string (simple objective)
  - A map with single key-value pair where value is a list of children
  """
  def validate_objective(objective) when is_binary(objective), do: :ok

  def validate_objective(objective) when is_map(objective) do
    case Map.to_list(objective) do
      [{title, children}] when is_binary(title) and is_list(children) ->
        :ok

      [{_, _}] ->
        {:error, "Invalid objective format. Expected {\"Title\": [children]}"}

      _ ->
        {:error, "Invalid objective format. Objective map must have exactly one key-value pair"}
    end
  end

  def validate_objective(_), do: {:error, "Invalid objective format. Must be string or map"}
end
