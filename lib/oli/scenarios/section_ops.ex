defmodule Oli.Scenarios.SectionOps do
  @moduledoc """
  Operations that can be applied to sections and products.
  Supports the revise operation for modifying section resource properties.
  """

  alias Oli.Auditing.Context
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Remix
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited
  alias Oli.Delivery.Settings.Audited, as: SettingsAudited
  alias Oli.Delivery.Settings.AssessmentSettings
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo

  @doc """
  Applies `ops` to `section` in order. Settings changes (`change`) are recorded in the Audit Log
  under `context`.
  """
  def apply_ops!(section, ops, %Context{} = context) do
    Enum.reduce(ops, section, fn op, acc_section ->
      apply_op(op, acc_section, context)
    end)
  end

  defp apply_op(%{"revise" => params}, section, context) do
    target = params["target"]
    set_params = params["set"] || %{}

    revise_section_resource!(section, target, set_params, context)
  end

  defp apply_op(%{"change" => params}, section, context) do
    change_section!(section, params, context)
  end

  defp apply_op(op, _section, _context) do
    raise "Unsupported section operation: #{inspect(op)}"
  end

  defp revise_section_resource!(section, target, set_params, context) do
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

      assessment_keys = MapSet.new(AssessmentSettings.supported_keys())

      {assessment_params, other_params} =
        Enum.split_with(update_params, fn {key, _value} ->
          MapSet.member?(assessment_keys, key)
        end)

      section =
        case assessment_params do
          [] ->
            section

          assessment_params ->
            # The section's hidden instructor passes the secure-delivery editor check.
            {:ok, {actor, _token}} = Sections.fetch_hidden_instructor(section.id)

            case SettingsAudited.update_assessment_settings(
                   Context.for_actor(actor, source: :scenario),
                   section,
                   section_resource.resource_id,
                   Map.new(assessment_params),
                   %{include_ungraded: true}
                 ) do
              {:ok, _result} ->
                section

              {:error, reason} ->
                raise "Failed to update assessment settings for '#{target}': #{inspect(reason)}"
            end
        end

      # Visibility is a curriculum change, saved as a remix
      {hidden_params, other_params} =
        Enum.split_with(other_params, fn {key, _value} -> key == :hidden end)

      section =
        case hidden_params do
          [] -> section
          [{:hidden, hidden}] -> set_hidden!(section, section_resource, hidden, context)
        end

      case other_params do
        [] ->
          section

        other_params ->
          case Sections.update_section_resource(section_resource, Map.new(other_params)) do
            {:ok, _updated_resource} ->
              section

            {:error, %Ecto.Changeset{errors: errors}} ->
              raise "Failed to update section resource '#{target}': #{inspect(errors)}"

            {:error, reason} ->
              raise "Failed to update section resource '#{target}': #{inspect(reason)}"
          end
      end
    else
      raise "Section resource '#{target}' not found in section"
    end
  end

  defp set_hidden!(section, %SectionResource{hidden: hidden}, hidden, _context), do: section

  defp set_hidden!(section, %SectionResource{resource_id: resource_id}, _hidden, context) do
    {:ok, state} = Remix.init_open_and_free(section)

    node =
      state.hierarchy
      |> Hierarchy.flatten_hierarchy()
      |> Enum.find(&(&1.resource_id == resource_id))

    {:ok, state} = Remix.toggle_hidden(state, node.uuid)

    case SectionsAudited.save_remix(context, state, nil) do
      {:ok, section} -> section
      {:error, reason} -> raise "Failed to change the visibility: #{inspect(reason)}"
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

  # Keys must name existing section fields; the facade rejects fields no settings form writes.
  defp change_section!(section, params, context) do
    change_params =
      Map.new(params, fn {key, value} ->
        {String.to_existing_atom(key), process_value(key, value)}
      end)

    case SectionsAudited.update_section_settings(
           context,
           section,
           change_params,
           Map.keys(change_params)
         ) do
      {:ok, updated_section} ->
        updated_section

      {:error, %Ecto.Changeset{} = changeset} ->
        raise "Failed to change section settings: #{inspect(changeset.errors)}"

      {:error, reason} ->
        raise "Failed to change section settings: #{inspect(reason)}"
    end
  end
end
