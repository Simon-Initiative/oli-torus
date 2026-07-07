defmodule Oli.Scenarios.Directives.Assert.InstructorDashboardAssertion do
  @moduledoc """
  Instructor-facing assertions for the Intelligent Dashboard snapshot projections.
  """

  alias Oli.Dashboard.Oracle.Result
  alias Oli.InstructorDashboard.DataSnapshot
  alias Oli.InstructorDashboard.DataSnapshot.Projections
  alias Oli.InstructorDashboard.OracleRegistry
  alias Oli.InstructorDashboard.StudentSupportParameters
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers

  @control_keys [:section, :scope, :tolerance]
  @default_tolerance 0.001
  @summary_recommendation_oracle :oracle_instructor_recommendation

  @spec assert(atom(), AssertDirective.t(), map()) ::
          {:ok, map(), VerificationResult.t()} | {:error, String.t()}
  def assert(capability, %AssertDirective{} = directive, state) do
    spec = spec_for(capability, directive)

    with {:ok, section} <- Helpers.get_section(state, spec.section),
         {:ok, scope} <- resolve_scope(section, Map.get(spec, :scope, "course")),
         {:ok, bundle} <- build_bundle(capability, section, scope, state) do
      actual = projection_view(capability, bundle)
      expected = expected_subset(spec)
      tolerance = Map.get(spec, :tolerance) || @default_tolerance
      mismatches = compare_subset(expected, actual, [], tolerance)

      verification =
        verification_result(
          capability,
          spec.section,
          scope_label(scope),
          expected,
          actual,
          mismatches
        )

      {:ok, state, verification}
    else
      {:error, reason} ->
        {:error, "Failed to assert instructor dashboard #{capability}: #{format_reason(reason)}"}
    end
  end

  defp spec_for(:summary, %AssertDirective{instructor_dashboard_summary: spec}), do: spec
  defp spec_for(:progress, %AssertDirective{instructor_dashboard_progress: spec}), do: spec

  defp spec_for(:student_support, %AssertDirective{instructor_dashboard_student_support: spec}),
    do: spec

  defp spec_for(:challenging_objectives, %AssertDirective{
         instructor_dashboard_challenging_objectives: spec
       }),
       do: spec

  defp spec_for(:assessments, %AssertDirective{instructor_dashboard_assessments: spec}), do: spec

  defp build_bundle(capability, section, scope, state) do
    dependency_profile = dependency_profile(capability)

    DataSnapshot.get_or_build(
      %{
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: section.id,
          user_id: dashboard_user_id(state),
          scope: scope
        },
        scope: scope
      },
      dependency_profile: dependency_profile,
      runtime_results_provider: runtime_results_provider(dependency_profile),
      projection_opts: projection_opts(state),
      request_token: "scenario-instructor-dashboard-#{capability}-#{section.id}"
    )
  end

  defp dependency_profile(capability) do
    Projections.dependencies()
    |> Map.fetch!(capability)
    |> maybe_remove_summary_recommendation(capability)
  end

  defp maybe_remove_summary_recommendation(profile, :summary) do
    %{
      profile
      | optional: Enum.reject(profile.optional, &(&1 == @summary_recommendation_oracle))
    }
  end

  defp maybe_remove_summary_recommendation(profile, _capability), do: profile

  defp runtime_results_provider(dependency_profile) do
    requested_oracles = Enum.uniq(dependency_profile.required ++ dependency_profile.optional)

    fn _request_token, misses, context, _scope ->
      requested_oracles
      |> Kernel.++(misses)
      |> Enum.uniq()
      |> Map.new(fn oracle_key ->
        {oracle_key, load_runtime_oracle(oracle_key, context)}
      end)
    end
  end

  defp load_runtime_oracle(oracle_key, context) do
    case OracleRegistry.oracle_module(oracle_key) do
      {:ok, module} ->
        case module.load(context, []) do
          {:ok, payload} ->
            Result.ok(oracle_key, payload,
              version: oracle_version(module),
              metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
            )

          {:error, reason} ->
            Result.error(oracle_key, reason,
              version: oracle_version(module),
              metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
            )
        end

      {:error, reason} ->
        Result.error(oracle_key, reason,
          metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
        )
    end
  end

  defp oracle_version(module),
    do: if(function_exported?(module, :version, 0), do: module.version(), else: 1)

  defp projection_opts(state) do
    [
      student_support_settings: StudentSupportParameters.default_settings(),
      now: state.scenario_time || DateTime.utc_now()
    ]
  end

  defp dashboard_user_id(%{current_author: %{id: id}}) when is_integer(id) and id > 0, do: id

  defp dashboard_user_id(%{users: users}) when is_map(users) do
    users
    |> Map.values()
    |> Enum.find_value(fn
      %{id: id} when is_integer(id) and id > 0 -> id
      _ -> nil
    end)
    |> case do
      nil -> 1
      id -> id
    end
  end

  defp dashboard_user_id(_state), do: 1

  defp resolve_scope(_section, nil), do: {:ok, %{container_type: :course, container_id: nil}}
  defp resolve_scope(_section, "course"), do: {:ok, %{container_type: :course, container_id: nil}}
  defp resolve_scope(_section, :course), do: {:ok, %{container_type: :course, container_id: nil}}

  defp resolve_scope(_section, "container:" <> id) do
    case Integer.parse(id) do
      {container_id, ""} when container_id > 0 ->
        {:ok, %{container_type: :container, container_id: container_id}}

      _ ->
        {:error, "Invalid dashboard container scope '#{id}'"}
    end
  end

  defp resolve_scope(section, %{container: container}),
    do: resolve_container_scope(section, container)

  defp resolve_scope(section, %{"container" => container}),
    do: resolve_container_scope(section, container)

  defp resolve_scope(_section, %{container_type: :container, container_id: id})
       when is_integer(id) and id > 0,
       do: {:ok, %{container_type: :container, container_id: id}}

  defp resolve_scope(_section, %{"container_type" => "container", "container_id" => id}),
    do: resolve_container_id_scope(id)

  defp resolve_scope(_section, other),
    do: {:error, "Unsupported dashboard scope #{inspect(other)}"}

  defp resolve_container_scope(_section, id) when is_integer(id) and id > 0,
    do: {:ok, %{container_type: :container, container_id: id}}

  defp resolve_container_scope(section, title) when is_binary(title) do
    case Integer.parse(title) do
      {id, ""} when id > 0 -> {:ok, %{container_type: :container, container_id: id}}
      _ -> container_scope_by_title(section, title)
    end
  end

  defp resolve_container_scope(_section, other),
    do: {:error, "Invalid dashboard container scope #{inspect(other)}"}

  defp resolve_container_id_scope(id) when is_integer(id) and id > 0,
    do: {:ok, %{container_type: :container, container_id: id}}

  defp resolve_container_id_scope(id) when is_binary(id) do
    case Integer.parse(id) do
      {container_id, ""} when container_id > 0 ->
        {:ok, %{container_type: :container, container_id: container_id}}

      _ ->
        {:error, "Invalid dashboard container_id #{inspect(id)}"}
    end
  end

  defp resolve_container_id_scope(id),
    do: {:error, "Invalid dashboard container_id #{inspect(id)}"}

  defp container_scope_by_title(section, title) do
    section.slug
    |> DeliveryResolver.full_hierarchy()
    |> find_node_by_title(title)
    |> case do
      nil -> {:error, "Container '#{title}' not found in section '#{section.slug}'"}
      node -> {:ok, %{container_type: :container, container_id: node.resource_id}}
    end
  end

  defp find_node_by_title(nil, _title), do: nil

  defp find_node_by_title(node, title) do
    cond do
      get_in(node, [Access.key(:revision), Access.key(:title)]) == title ->
        node

      get_in(node, [Access.key(:section_resource), Access.key(:title)]) == title ->
        node

      true ->
        Enum.find_value(node.children || [], &find_node_by_title(&1, title))
    end
  end

  defp projection_view(:summary, %{projections: %{summary: projection}}) do
    summary_tile = Map.get(projection, :summary_tile, %{})

    %{
      scope: Map.get(projection, :scope, %{}),
      scope_label: get_in(projection, [:scope, :label]),
      course_title: get_in(projection, [:scope, :course_title]),
      metrics: Map.get(projection, :metrics, %{}),
      total_students: Map.get(projection, :total_students),
      cards: cards_by_id(Map.get(summary_tile, :cards, [])),
      available_slots: Map.get(summary_tile, :available_slots, []),
      missing_slots: Map.get(summary_tile, :missing_slots, [])
    }
  end

  defp projection_view(:progress, %{projections: %{progress: projection}}) do
    tile = Map.get(projection, :progress_tile, %{})

    tile
    |> Map.put(:items, progress_items_by_label(Map.get(tile, :series_all, [])))
    |> Map.put(:series, Map.get(tile, :series, []))
    |> Map.put(:series_all, Map.get(tile, :series_all, []))
  end

  defp projection_view(:student_support, %{projections: %{student_support: projection}}) do
    support = Map.get(projection, :support, %{})

    support
    |> Map.put(:has_activity_data, Map.get(support, :has_activity_data?))
    |> Map.put(:buckets, buckets_by_id(Map.get(support, :buckets, [])))
  end

  defp projection_view(:challenging_objectives, %{
         projections: %{challenging_objectives: projection}
       }) do
    projection
    |> Map.put(:scope_label, get_in(projection, [:scope, :label]))
    |> Map.put(:course_title, get_in(projection, [:scope, :course_title]))
    |> Map.put(:rows_by_title, rows_by_title(Map.get(projection, :rows, [])))
  end

  defp projection_view(:assessments, %{projections: %{assessments: projection}}) do
    assessments = Map.get(projection, :assessments, %{})

    assessments
    |> Map.put(:has_assessments, Map.get(assessments, :has_assessments?))
    |> Map.put(:rows_by_title, rows_by_title(Map.get(assessments, :rows, [])))
  end

  defp projection_view(capability, bundle) do
    Map.get(bundle.projections, capability, %{})
  end

  defp cards_by_id(cards) do
    Map.new(cards, fn card -> {card.id |> Atom.to_string(), card} end)
  end

  defp progress_items_by_label(items) do
    Map.new(items, fn item ->
      normalized =
        item
        |> Map.put(:completed_count, Map.get(item, :count))
        |> Map.put(:completed_percent, Map.get(item, :percent))

      {item.label, normalized}
    end)
  end

  defp buckets_by_id(buckets) do
    Map.new(buckets, fn bucket ->
      students = Map.get(bucket, :students, [])

      normalized =
        bucket
        |> Map.put(:student_names, Enum.map(students, &Map.get(&1, :display_name)))
        |> Map.put(:student_emails, Enum.map(students, &Map.get(&1, :email)))

      {bucket.id, normalized}
    end)
  end

  defp rows_by_title(rows) do
    Map.new(rows, fn row -> {Map.get(row, :title), row} end)
  end

  defp expected_subset(spec) do
    spec
    |> Map.drop(@control_keys)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp compare_subset(expected, actual, path, tolerance) when is_map(expected) do
    Enum.flat_map(expected, fn {key, expected_value} ->
      case fetch_field(actual, key) do
        {:ok, actual_value} ->
          compare_subset(expected_value, actual_value, path ++ [key], tolerance)

        :error ->
          [mismatch(path ++ [key], expected_value, :missing)]
      end
    end)
  end

  defp compare_subset(expected, actual, path, tolerance)
       when is_list(expected) and is_list(actual) do
    expected
    |> Enum.with_index()
    |> Enum.flat_map(fn {expected_value, index} ->
      case Enum.fetch(actual, index) do
        {:ok, actual_value} ->
          compare_subset(expected_value, actual_value, path ++ [index], tolerance)

        :error ->
          [mismatch(path ++ [index], expected_value, :missing)]
      end
    end)
  end

  defp compare_subset(expected, actual, path, tolerance) do
    if values_match?(expected, actual, tolerance) do
      []
    else
      [mismatch(path, expected, actual)]
    end
  end

  defp fetch_field(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) ->
        {:ok, Map.get(map, key)}

      is_atom(key) and Map.has_key?(map, Atom.to_string(key)) ->
        {:ok, Map.get(map, Atom.to_string(key))}

      is_binary(key) ->
        case existing_atom(key) do
          {:ok, atom_key} when is_map_key(map, atom_key) -> {:ok, Map.get(map, atom_key)}
          _ -> :error
        end

      true ->
        :error
    end
  end

  defp fetch_field(_actual, _key), do: :error

  defp existing_atom(key) when is_binary(key) do
    {:ok, String.to_existing_atom(key)}
  rescue
    ArgumentError -> :error
  end

  defp values_match?(expected, actual, tolerance) do
    cond do
      numeric?(expected) and numeric?(actual) ->
        abs(to_number(expected) - to_number(actual)) <= tolerance

      is_atom(actual) and is_binary(expected) ->
        Atom.to_string(actual) == expected

      is_atom(expected) and is_binary(actual) ->
        Atom.to_string(expected) == actual

      true ->
        expected == actual
    end
  end

  defp numeric?(value) when is_integer(value) or is_float(value), do: true

  defp numeric?(value) when is_binary(value) do
    case Float.parse(value) do
      {_number, ""} -> true
      _ -> false
    end
  end

  defp numeric?(_value), do: false

  defp to_number(value) when is_integer(value) or is_float(value), do: value * 1.0

  defp to_number(value) when is_binary(value) do
    {number, ""} = Float.parse(value)
    number
  end

  defp mismatch(path, expected, actual) do
    %{path: format_path(path), expected: expected, actual: actual}
  end

  defp verification_result(capability, section_name, scope_label, expected, actual, []) do
    %VerificationResult{
      to: section_name,
      passed: true,
      message:
        "Instructor dashboard #{capability} assertion passed for section '#{section_name}' scope '#{scope_label}'",
      expected: expected,
      actual: actual
    }
  end

  defp verification_result(capability, section_name, scope_label, expected, actual, mismatches) do
    %VerificationResult{
      to: section_name,
      passed: false,
      message:
        "Instructor dashboard #{capability} assertion failed for section '#{section_name}' scope '#{scope_label}': " <>
          Enum.map_join(mismatches, "; ", fn mismatch ->
            "#{mismatch.path} expected #{inspect(mismatch.expected)}, got #{inspect(mismatch.actual)}"
          end),
      expected: expected,
      actual: actual
    }
  end

  defp scope_label(%{container_type: :course}), do: "course"
  defp scope_label(%{container_type: :container, container_id: id}), do: "container:#{id}"
  defp scope_label(scope), do: inspect(scope)

  defp format_path([]), do: "$"

  defp format_path(path) do
    Enum.reduce(path, "$", fn
      item, acc when is_integer(item) -> "#{acc}[#{item}]"
      item, acc -> "#{acc}.#{item}"
    end)
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
