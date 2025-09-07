defmodule Oli.Scenarios.Directives.Assert.ResourceAssertion do
  @moduledoc """
  Handles resource property assertions for projects and sections.
  """

  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Engine
  alias Oli.Publishing.{DeliveryResolver, AuthoringResolver}
  alias Oli.Repo
  alias Oli.Delivery.Sections.SectionResource

  @doc """
  Asserts that properties of a resource match expected values.
  """
  def assert(%AssertDirective{resource: resource_spec}, state) when is_map(resource_spec) do
    to_name = resource_spec.to
    target_name = resource_spec.target
    expected_properties = resource_spec.resource || %{}

    # Determine if target is a project or section
    {target_type, target} = get_target(state, to_name)

    # Get the resource data for verification
    {actual_data, data_type} =
      case target_type do
        :project ->
          get_project_resource(state, to_name, target_name)

        :section ->
          get_section_resource(target, target_name)
      end

    verification_result =
      if actual_data do
        # Compare the expected properties with actual
        verify_resource_data(to_name, target_name, expected_properties, actual_data, data_type)
      else
        %VerificationResult{
          to: to_name,
          passed: false,
          message: "Resource '#{target_name}' not found in '#{to_name}'"
        }
      end

    {:ok, state, verification_result}
  end
  
  def assert(%AssertDirective{resource: nil}, state), do: {:ok, state, nil}

  defp get_target(state, name) do
    # Check for product first
    case Engine.get_product(state, name) do
      nil ->
        # Then check for section
        case Engine.get_section(state, name) do
          nil ->
            # Finally check for project
            case Engine.get_project(state, name) do
              nil -> raise "Target '#{name}' not found"
              project -> {:project, project}
            end

          section ->
            {:section, section}
        end

      product ->
        # Products are sections behind the scenes
        {:section, product}
    end
  end

  defp get_project_resource(state, to_name, target_name) do
    # For projects, get the revision from the state
    built_project = Engine.get_project(state, to_name)

    if built_project do
      # First try to find by title in the project's rev_by_title map
      rev = built_project.rev_by_title[target_name]

      if rev do
        # Get fresh revision from database
        fresh_rev =
          AuthoringResolver.from_resource_id(built_project.project.slug, rev.resource_id)

        {fresh_rev, :revision}
      else
        {nil, nil}
      end
    else
      {nil, nil}
    end
  end

  defp get_section_resource(section, target_name) do
    # For sections, only consider the SectionResource record
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)
    node = find_node_by_title_in_hierarchy(hierarchy, target_name)

    if node && node.section_resource do
      # Get fresh section resource from database
      section_resource = Repo.get!(SectionResource, node.section_resource.id)

      {section_resource, :section_resource}
    else
      {nil, nil}
    end
  end

  defp find_node_by_title_in_hierarchy(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, title) do
    cond do
      node.revision && node.revision.title == title ->
        node

      node.section_resource && node.section_resource.title == title ->
        node

      true ->
        Enum.find_value(node.children || [], fn child ->
          find_node_by_title_in_hierarchy(child, title)
        end)
    end
  end

  defp find_node_by_title_in_hierarchy(_, _), do: nil

  defp verify_resource_data(to_name, target_name, expected_properties, actual_data, _data_type) do
    try do
      Enum.each(expected_properties, fn {key, expected_value} ->
        # Process the expected value (handle @atom() syntax and type conversion)
        expected = process_expected_value(key, expected_value)

        # Get the actual value from the data (works for both revision and section_resource)
        actual = Map.get(actual_data, String.to_atom(key))

        if actual != expected do
          raise "Property '#{key}' mismatch for '#{target_name}': expected #{inspect(expected)}, got #{inspect(actual)}"
        end
      end)

      %VerificationResult{
        to: to_name,
        passed: true,
        message: "Resource '#{target_name}' properties match expected"
      }
    rescue
      e ->
        %VerificationResult{
          to: to_name,
          passed: false,
          message: Exception.message(e)
        }
    end
  end

  defp process_expected_value(_key, value) when is_binary(value) do
    cond do
      # Handle @atom(...) format
      String.starts_with?(value, "@atom(") ->
        atom_str =
          value
          |> String.trim_leading("@atom(")
          |> String.trim_trailing(")")

        String.to_atom(atom_str)

      # Handle boolean strings
      value in ["true", "false"] ->
        value == "true"

      # Handle integer strings
      String.match?(value, ~r/^\d+$/) ->
        String.to_integer(value)

      # Handle float strings
      String.match?(value, ~r/^\d+\.\d+$/) ->
        String.to_float(value)

      # Otherwise keep as string
      true ->
        value
    end
  end

  defp process_expected_value(_key, value) when is_boolean(value), do: value
  defp process_expected_value(_key, value) when is_number(value), do: value
  defp process_expected_value(_key, value) when is_atom(value), do: value
  defp process_expected_value(_key, value), do: value
end