defmodule Oli.Scenarios.SectionOps do
  @moduledoc """
  Operations that can be applied to sections and products.
  Supports the revise operation for modifying section resource properties.
  """

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo

  def apply_ops!(section, ops) do
    Enum.reduce(ops, section, fn op, acc_section ->
      apply_op(op, acc_section)
    end)
  end

  defp apply_op(%{"revise" => params}, section) do
    target = params["target"]
    set_params = params["set"] || %{}

    revise_section_resource!(section, target, set_params)
  end

  defp apply_op(%{"change" => params}, section) do
    change_section!(section, params)
  end

  defp apply_op(op, _section) do
    raise "Unsupported section operation: #{inspect(op)}"
  end

  defp revise_section_resource!(section, target, set_params) do
    # Get the hierarchy to find the target resource
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)
    node = find_node_by_title(hierarchy, target)

    if node && node.section_resource do
      # Get the section resource
      section_resource = Repo.get!(SectionResource, node.section_resource.id)

      # Process the parameters to handle special values
      update_params =
        set_params
        |> Enum.map(fn {key, value} ->
          {String.to_atom(key), process_value(key, value)}
        end)
        |> Enum.into(%{})

      # Update the section resource
      case Sections.update_section_resource(section_resource, update_params) do
        {:ok, _updated_resource} ->
          # Return the section (it will be refreshed on next read)
          section

        {:error, changeset} ->
          raise "Failed to update section resource '#{target}': #{inspect(changeset.errors)}"
      end
    else
      raise "Section resource '#{target}' not found in section"
    end
  end

  defp find_node_by_title(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, title) do
    cond do
      node.revision && node.revision.title == title ->
        node

      node.section_resource && node.section_resource.title == title ->
        node

      true ->
        Enum.find_value(node.children || [], fn child ->
          find_node_by_title(child, title)
        end)
    end
  end

  defp find_node_by_title(_, _), do: nil

  # Process special value formats (same as in Ops module)
  defp process_value(_key, value) when is_binary(value) do
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

  defp process_value(_key, value) when is_boolean(value), do: value
  defp process_value(_key, value) when is_number(value), do: value
  defp process_value(_key, value) when is_atom(value), do: value
  defp process_value(_key, value), do: value

  defp change_section!(section, params) do
    # Process the parameters to convert special values
    change_params =
      params
      |> Enum.map(fn {key, value} ->
        {String.to_atom(key), process_value(key, value)}
      end)
      |> Enum.into(%{})

    # Update the section using standard changeset
    case Sections.update_section(section, change_params) do
      {:ok, updated_section} ->
        updated_section

      {:error, changeset} ->
        raise "Failed to change section settings: #{inspect(changeset.errors)}"
    end
  end
end
