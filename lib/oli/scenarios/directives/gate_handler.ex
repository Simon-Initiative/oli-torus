defmodule Oli.Scenarios.Directives.GateHandler do
  @moduledoc """
  Handles gate directives for creating gating conditions and student-specific exceptions.
  """

  alias Oli.Delivery.Gating
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, GateDirective}
  alias Oli.Scenarios.Engine

  def handle(%GateDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, section} <- fetch_section(state, directive.section),
         {:ok, parent_gate} <- fetch_parent_gate(state, directive.parent),
         {:ok, target_resource_id} <- resolve_target_resource_id(section, directive, parent_gate),
         {:ok, source_resource_id} <- resolve_source_resource_id(section, directive.source),
         {:ok, student} <- fetch_student(state, directive.student),
         attrs <-
           build_attrs(
             directive,
             section.id,
             target_resource_id,
             source_resource_id,
             student,
             parent_gate
           ),
         {:ok, gate} <- Gating.create_gating_condition(attrs),
         {:ok, updated_section} <- refresh_section(section),
         {:ok, updated_state} <- update_state(state, directive, gate, updated_section) do
      {:ok, updated_state}
    else
      {:error, reason} ->
        {:error, "Failed to create gate: #{reason}"}
    end
  end

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end

  defp fetch_parent_gate(_state, nil), do: {:ok, nil}

  defp fetch_parent_gate(state, gate_name) do
    case Engine.get_gate(state, gate_name) do
      nil -> {:error, "Gate '#{gate_name}' not found"}
      gate -> {:ok, gate}
    end
  end

  defp resolve_target_resource_id(section, %GateDirective{target: target}, _parent_gate)
       when is_binary(target) do
    {:ok, resolve_resource_id!(section, target)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp resolve_target_resource_id(_section, %GateDirective{target: nil}, %{
         resource_id: resource_id
       }) do
    {:ok, resource_id}
  end

  defp resolve_target_resource_id(_section, %GateDirective{target: nil}, nil) do
    {:error, "gate requires a target unless it inherits one from a parent gate"}
  end

  defp resolve_source_resource_id(_section, nil), do: {:ok, nil}

  defp resolve_source_resource_id(section, source_title) do
    {:ok, resolve_resource_id!(section, source_title)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp fetch_student(_state, nil), do: {:ok, nil}

  defp fetch_student(state, student_name) do
    case Engine.get_user(state, student_name) do
      nil -> {:error, "User '#{student_name}' not found"}
      student -> {:ok, student}
    end
  end

  defp build_attrs(
         directive,
         section_id,
         target_resource_id,
         source_resource_id,
         student,
         parent_gate
       ) do
    %{
      type: directive.type,
      section_id: section_id,
      resource_id: target_resource_id,
      user_id: if(student, do: student.id, else: nil),
      parent_id: if(parent_gate, do: parent_gate.id, else: nil),
      graded_resource_policy: directive.graded_resource_policy || :allows_review,
      data:
        %{}
        |> put_if_present(:resource_id, source_resource_id)
        |> put_if_present(:start_datetime, directive.start)
        |> put_if_present(:end_datetime, directive.end)
        |> put_if_present(:minimum_percentage, directive.minimum_percentage)
    }
  end

  defp refresh_section(section) do
    with {:ok, _updated} <- Gating.update_resource_gating_index(section) do
      {:ok, Sections.get_section!(section.id)}
    end
  end

  defp update_state(state, directive, gate, updated_section) do
    updated_state =
      state
      |> Engine.put_section(directive.section, updated_section)
      |> maybe_put_gate(directive.name, gate)

    {:ok, updated_state}
  end

  defp maybe_put_gate(state, nil, _gate), do: state
  defp maybe_put_gate(state, gate_name, gate), do: Engine.put_gate(state, gate_name, gate)

  defp resolve_resource_id!(section, title) do
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    case find_node_by_title(hierarchy, title) do
      nil -> raise "Resource '#{title}' not found in section '#{section.slug}'"
      node -> node.revision.resource_id
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

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
