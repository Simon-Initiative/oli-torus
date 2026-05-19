defmodule Oli.Scenarios.Directives.Assert.GatingAssertion do
  @moduledoc """
  Handles persisted gate and effective access assertions for scenario tests.
  """

  alias Oli.Delivery.Gating
  alias Oli.Delivery.Sections
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers
  alias Oli.Scenarios.Engine
  alias Oli.Publishing.DeliveryResolver

  @float_tolerance 0.0001

  def assert(%AssertDirective{gating: gating_data}, state) when is_map(gating_data) do
    with {:ok, config_result} <- maybe_verify_gate_config(gating_data, state),
         {:ok, access_result} <- maybe_verify_access(gating_data, state) do
      verification =
        build_verification_result(
          gating_data,
          merge_expected(config_result, access_result),
          merge_actual(config_result, access_result),
          [config_result, access_result]
        )

      {:ok, state, verification}
    else
      {:error, reason} ->
        {:error, "Failed to assert gating: #{reason}"}
    end
  end

  def assert(%AssertDirective{gating: nil}, state), do: {:ok, state, nil}

  defp maybe_verify_gate_config(gating_data, state) do
    if gate_config_requested?(gating_data) do
      verify_gate_config(gating_data, state)
    else
      {:ok, nil}
    end
  end

  defp maybe_verify_access(gating_data, state) do
    if access_assertion_requested?(gating_data) do
      verify_access(gating_data, state)
    else
      {:ok, nil}
    end
  end

  defp verify_gate_config(gating_data, state) do
    with {:ok, expected_student} <- resolve_optional_student(state, gating_data.student),
         {:ok, resolved} <- resolve_gate_for_assertion(gating_data, state, expected_student) do
      case resolved do
        {:verification, verification} ->
          {:ok, verification}

        {:gate, gate, section, locator_description} ->
          expected = %{
            gate: gating_data.gate,
            type: gating_data.type,
            target: gating_data.target,
            source: gating_data.source,
            minimum_percentage: gating_data.minimum_percentage,
            start: gating_data.start,
            end: gating_data.end,
            student: gating_data.student
          }

          actual = gate_summary(gate, section, state)

          failures =
            []
            |> compare_value("type", gating_data.type, gate.type)
            |> compare_value("target", gating_data.target, actual.target)
            |> compare_value("source", gating_data.source, actual.source)
            |> compare_float(
              "minimum_percentage",
              gating_data.minimum_percentage,
              actual.minimum_percentage
            )
            |> compare_value("start", gating_data.start, actual.start)
            |> compare_value("end", gating_data.end, actual.end)
            |> compare_value("student", gating_data.student, actual.student)

          message =
            if failures == [] do
              "Gate assertion passed for #{locator_description}"
            else
              "Gate assertion failed for #{locator_description}: #{Enum.join(failures, "; ")}"
            end

          {:ok,
           %{
             expected: compact_map(expected),
             actual: actual,
             passed: failures == [],
             message: message
           }}
      end
    end
  end

  defp verify_access(gating_data, state) do
    with {:ok, section_name} <- require_field(gating_data.section, "gating.section"),
         {:ok, student_name} <- require_field(gating_data.student, "gating.student"),
         {:ok, resource_title} <- require_field(gating_data.resource, "gating.resource"),
         {:ok, section} <- Helpers.get_section(state, section_name),
         {:ok, student} <- Helpers.get_user(state, student_name),
         {:ok, resource_id} <- resolve_resource_id(section, resource_title) do
      blocking_gates = Gating.blocked_by(section, student, resource_id)
      actual_accessible = blocking_gates == []
      actual_blocking_types = blocking_gates |> Enum.map(& &1.type) |> Enum.sort()
      actual_blocking_count = length(blocking_gates)

      expected = %{
        section: gating_data.section,
        student: gating_data.student,
        resource: gating_data.resource,
        accessible: gating_data.accessible,
        blocking_types: gating_data.blocking_types,
        blocking_count: gating_data.blocking_count
      }

      actual = %{
        section: gating_data.section,
        student: gating_data.student,
        resource: gating_data.resource,
        accessible: actual_accessible,
        blocking_types: actual_blocking_types,
        blocking_count: actual_blocking_count
      }

      failures =
        []
        |> compare_value("accessible", gating_data.accessible, actual_accessible)
        |> compare_value(
          "blocking_types",
          normalize_gate_types(gating_data.blocking_types),
          actual_blocking_types
        )
        |> compare_value("blocking_count", gating_data.blocking_count, actual_blocking_count)

      message =
        if failures == [] do
          "Access assertion passed for student '#{student_name}' to resource '#{resource_title}' in section '#{section_name}'"
        else
          "Access assertion failed for student '#{student_name}' to resource '#{resource_title}' in section '#{section_name}': #{Enum.join(failures, "; ")}"
        end

      {:ok,
       %{
         expected: compact_map(expected),
         actual: actual,
         passed: failures == [],
         message: message
       }}
    end
  end

  defp resolve_gate_for_assertion(gating_data, state, expected_student) do
    case gating_data.gate do
      nil ->
        resolve_gate_by_filters(gating_data, state, expected_student)

      gate_name ->
        case Engine.get_gate(state, gate_name) do
          nil ->
            {:ok,
             {:verification,
              %{
                expected: compact_map(%{gate: gate_name}),
                actual: %{gate: nil},
                passed: false,
                message: "Gate assertion failed for named gate '#{gate_name}': gate was not found"
              }}}

          gate ->
            section = get_gate_section(state, gate.section_id)
            {:ok, {:gate, gate, section, "named gate '#{gate_name}'"}}
        end
    end
  end

  defp resolve_gate_by_filters(gating_data, state, expected_student) do
    with {:ok, section_name} <- require_field(gating_data.section, "gating.section"),
         {:ok, section} <- Helpers.get_section(state, section_name),
         {:ok, expected_target_id} <- resolve_optional_resource_id(section, gating_data.target),
         {:ok, expected_source_id} <- resolve_optional_resource_id(section, gating_data.source) do
      matches =
        Gating.list_gating_conditions(section.id)
        |> Enum.filter(fn gate ->
          gate_matches_filters?(
            gate,
            gating_data.type,
            expected_target_id,
            expected_source_id,
            expected_student
          )
        end)

      case matches do
        [gate] ->
          {:ok,
           {:gate, gate, section,
            "section '#{section_name}' filters #{describe_gate_filters(gating_data)}"}}

        [] ->
          {:ok,
           {:verification,
            %{
              expected:
                compact_map(%{
                  section: section_name,
                  type: gating_data.type,
                  target: gating_data.target,
                  source: gating_data.source,
                  student: gating_data.student
                }),
              actual: %{match_count: 0},
              passed: false,
              message:
                "Gate assertion failed for section '#{section_name}': no gating condition matched #{describe_gate_filters(gating_data)}"
            }}}

        gates ->
          {:ok,
           {:verification,
            %{
              expected:
                compact_map(%{
                  section: section_name,
                  type: gating_data.type,
                  target: gating_data.target,
                  source: gating_data.source,
                  student: gating_data.student
                }),
              actual: %{match_count: length(gates)},
              passed: false,
              message:
                "Gate assertion failed for section '#{section_name}': multiple gating conditions matched #{describe_gate_filters(gating_data)}"
            }}}
      end
    end
  end

  defp resolve_optional_student(_state, nil), do: {:ok, nil}

  defp resolve_optional_student(state, student_name) do
    Helpers.get_user(state, student_name)
  end

  defp gate_matches_filters?(
         gate,
         expected_type,
         expected_target_id,
         expected_source_id,
         expected_student
       ) do
    matches_type?(gate, expected_type) and
      matches_target?(gate, expected_target_id) and
      matches_source?(gate, expected_source_id) and
      matches_student?(gate, expected_student)
  end

  defp matches_type?(_gate, nil), do: true
  defp matches_type?(gate, expected_type), do: gate.type == expected_type

  defp matches_target?(_gate, nil), do: true
  defp matches_target?(gate, expected_target_id), do: gate.resource_id == expected_target_id

  defp matches_source?(_gate, nil), do: true

  defp matches_source?(gate, expected_source_id) do
    source_resource_id(gate) == expected_source_id
  end

  defp matches_student?(_gate, nil), do: true
  defp matches_student?(gate, student), do: gate.user_id == student.id

  defp gate_summary(nil, _section, _state), do: %{gate: nil}

  defp gate_summary(gate, section, state) do
    %{
      gate: gate.id,
      type: gate.type,
      target: resolve_resource_title(section, gate.resource_id),
      source: resolve_resource_title(section, source_resource_id(gate)),
      minimum_percentage: minimum_percentage(gate),
      start: start_datetime(gate),
      end: end_datetime(gate),
      student: resolve_user_name(state, gate.user_id)
    }
  end

  defp source_resource_id(%{data: %{resource_id: resource_id}}), do: resource_id
  defp source_resource_id(_), do: nil

  defp minimum_percentage(%{data: %{minimum_percentage: minimum_percentage}}),
    do: minimum_percentage

  defp minimum_percentage(_), do: nil

  defp start_datetime(%{data: %{start_datetime: start_datetime}}), do: start_datetime
  defp start_datetime(_), do: nil

  defp end_datetime(%{data: %{end_datetime: end_datetime}}), do: end_datetime
  defp end_datetime(_), do: nil

  defp get_gate_section(state, section_id) do
    Enum.find(Map.values(state.sections), fn section -> section.id == section_id end) ||
      Sections.get_section!(section_id)
  end

  defp resolve_user_name(_state, nil), do: nil

  defp resolve_user_name(state, user_id) do
    Enum.find_value(state.users, fn {name, user} ->
      if user.id == user_id, do: name, else: nil
    end)
  end

  defp resolve_optional_resource_id(_section, nil), do: {:ok, nil}

  defp resolve_optional_resource_id(section, title) do
    resolve_resource_id(section, title)
  end

  defp resolve_resource_id(section, title) when is_binary(title) do
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    case find_node_by_title(hierarchy, title) do
      nil -> {:error, "Resource '#{title}' not found in section '#{section.slug}'"}
      node -> {:ok, node.revision.resource_id}
    end
  end

  defp resolve_resource_title(_section, nil), do: nil

  defp resolve_resource_title(section, resource_id) do
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    case find_node_by_resource_id(hierarchy, resource_id) do
      nil -> nil
      node -> node.revision.title
    end
  end

  defp find_node_by_title(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, title) do
    cond do
      node.revision && node.revision.title == title ->
        node

      true ->
        Enum.find_value(node.children || [], fn child ->
          find_node_by_title(child, title)
        end)
    end
  end

  defp find_node_by_title(_, _), do: nil

  defp find_node_by_resource_id(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, resource_id) do
    cond do
      node.revision && node.revision.resource_id == resource_id ->
        node

      true ->
        Enum.find_value(node.children || [], fn child ->
          find_node_by_resource_id(child, resource_id)
        end)
    end
  end

  defp find_node_by_resource_id(_, _), do: nil

  defp build_verification_result(gating_data, expected, actual, results) do
    failures =
      results
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(& &1.passed)
      |> Enum.map(& &1.message)

    messages =
      results
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.message)

    %VerificationResult{
      to: gating_data.gate || gating_data.section || "gating",
      passed: failures == [],
      message: Enum.join(messages, " | "),
      expected: expected,
      actual: actual
    }
  end

  defp compare_value(failures, _label, nil, _actual), do: failures

  defp compare_value(failures, label, expected, actual) do
    if expected == actual do
      failures
    else
      failures ++ ["expected #{label}=#{inspect(expected)}, got #{inspect(actual)}"]
    end
  end

  defp compare_float(failures, _label, nil, _actual), do: failures

  defp compare_float(failures, label, expected, nil) do
    failures ++ ["expected #{label}=#{inspect(expected)}, got nil"]
  end

  defp compare_float(failures, label, expected, actual) do
    if abs(expected - actual) < @float_tolerance do
      failures
    else
      failures ++ ["expected #{label}=#{inspect(expected)}, got #{inspect(actual)}"]
    end
  end

  defp describe_gate_filters(gating_data) do
    gating_data
    |> Map.take([:type, :target, :source, :student])
    |> compact_map()
    |> Enum.map(fn {key, value} -> "#{key}=#{inspect(value)}" end)
    |> Enum.join(", ")
  end

  defp normalize_gate_types(nil), do: nil
  defp normalize_gate_types(types), do: Enum.sort(types)

  defp merge_expected(config_result, access_result) do
    [config_result, access_result]
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(%{}, fn result, acc -> Map.merge(acc, result.expected) end)
  end

  defp merge_actual(config_result, access_result) do
    [config_result, access_result]
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(%{}, fn result, acc -> Map.merge(acc, result.actual) end)
  end

  defp gate_config_requested?(gating_data) do
    not is_nil(gating_data.gate) or
      not is_nil(gating_data.type) or
      not is_nil(gating_data.target) or
      not is_nil(gating_data.source) or
      not is_nil(gating_data.minimum_percentage) or
      not is_nil(gating_data.start) or
      not is_nil(gating_data.end)
  end

  defp access_assertion_requested?(gating_data) do
    not is_nil(gating_data.accessible) or
      not is_nil(gating_data.resource) or
      not is_nil(gating_data.blocking_types) or
      not is_nil(gating_data.blocking_count)
  end

  defp require_field(nil, field_name),
    do: {:error, "#{field_name} is required for this gating assertion"}

  defp require_field(value, _field_name), do: {:ok, value}

  defp compact_map(map) do
    Enum.reduce(map, %{}, fn
      {_key, nil}, acc -> acc
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end
end
