defmodule Oli.Scenarios.Directives.ActivityBankHandler do
  @moduledoc """
  Handles activity_bank directives by executing author-facing Activity Bank
  operations against the non-UI application boundary.
  """

  alias Oli.Activities
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Authoring.Editing.ActivityBank
  alias Oli.Authoring.Locks
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Scenarios.DirectiveTypes.{ActivityBankDirective, ExecutionState, VerificationResult}
  alias Oli.TorusDoc.ActivityConverter

  @default_paging %{"limit" => 25, "offset" => 0}

  def handle(%ActivityBankDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, author} <- validate_author(state.current_author),
         {:ok, project_name} <- validate_project_name(directive.project),
         {:ok, built_project} <- get_project(project_name, state),
         {:ok, final_state, assertions} <-
           execute_ops(directive.ops || [], project_name, built_project, author, state) do
      verification = build_verification(project_name, assertions)
      {:ok, final_state, verification}
    else
      {:error, reason} ->
        {:error, "Failed to execute activity_bank directive: #{format_error(reason)}"}
    end
  end

  defp execute_ops(ops, project_name, built_project, author, state) do
    Enum.reduce_while(ops, {:ok, state, []}, fn %{action: action, data: data},
                                                {:ok, acc_state, assertions} ->
      case execute_op(action, data, project_name, built_project, author, acc_state) do
        {:ok, new_state} ->
          {:cont, {:ok, new_state, assertions}}

        {:ok, new_state, assertion_results} when is_list(assertion_results) ->
          {:cont, {:ok, new_state, [assertion_results | assertions]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, final_state, assertions} ->
        {:ok, final_state, assertions |> Enum.reverse() |> List.flatten()}

      error ->
        error
    end
  end

  defp execute_op("create", data, project_name, built_project, author, state) do
    with {:ok, attrs} <- normalize_create_attrs(data),
         {:ok, {revision, _content}} <-
           ActivityBank.create(built_project.project.slug, author, attrs) do
      {:ok, put_activity(state, project_name, revision, data["title"], data["virtual_id"])}
    end
  end

  defp execute_op(
         "create_bulk",
         %{"activities" => activities},
         project_name,
         built_project,
         author,
         state
       ) do
    with {:ok, attrs_list} <- normalize_bulk_create_attrs(activities),
         {:ok, created} <-
           ActivityBank.create_bulk(built_project.project.slug, author, attrs_list) do
      updated_state =
        attrs_list
        |> Enum.zip(created)
        |> Enum.reduce(state, fn {attrs, %{activity: revision}}, acc ->
          put_activity(acc, project_name, revision, attrs.title, attrs.virtual_id)
        end)

      {:ok, updated_state}
    end
  end

  defp execute_op("query", data, _project_name, built_project, author, state) do
    with {:ok, logic} <- query_logic(data, built_project),
         {:ok, %Result{} = result} <-
           ActivityBank.query(
             built_project.project.slug,
             author,
             logic,
             Map.get(data, "paging", @default_paging)
           ),
         assertion_results <- expectation_assertions(data["expect"], result, data["name"]) do
      state = put_query_result(state, data["name"], result)
      {:ok, state, assertion_results}
    end
  end

  defp execute_op("edit", data, project_name, built_project, author, state) do
    with {:ok, revision} <- resolve_activity(data, project_name, built_project, state),
         {:ok, _lock} <-
           ensure_activity_lock(built_project.project.slug, author, revision.resource_id),
         {:ok, update} <- normalize_update(data["set"] || %{}, built_project),
         {:ok, updated_revision} <-
           ActivityBank.update(
             built_project.project.slug,
             author,
             revision.resource_id,
             Map.put_new(update, "releaseLock", true)
           ) do
      {:ok, update_activity(state, project_name, revision, updated_revision, data["virtual_id"])}
    end
  end

  defp execute_op("delete", data, project_name, built_project, author, state) do
    with {:ok, revision} <- resolve_activity(data, project_name, built_project, state),
         {:ok, _lock} <-
           ensure_activity_lock(built_project.project.slug, author, revision.resource_id),
         {:ok, _deleted_revision} <-
           ActivityBank.delete(built_project.project.slug, author, revision.resource_id) do
      {:ok, remove_activity(state, project_name, revision, data)}
    end
  end

  defp execute_op("duplicate", data, project_name, built_project, author, state) do
    with {:ok, revision} <- resolve_activity(data, project_name, built_project, state),
         {:ok, attrs} <- duplicate_attrs(revision, data),
         {:ok, {new_revision, _content}} <-
           ActivityBank.create(built_project.project.slug, author, attrs) do
      {:ok,
       put_activity(
         state,
         project_name,
         new_revision,
         attrs.title,
         data["new_virtual_id"]
       )}
    end
  end

  defp execute_op("assert", data, _project_name, _built_project, _author, state) do
    case Map.get(state.activity_bank_results, data["result"]) do
      nil ->
        {:error, "Activity Bank result '#{data["result"]}' not found"}

      %Result{} = result ->
        {:ok, state, expectation_assertions(data["expect"], result, data["result"])}
    end
  end

  defp execute_op(action, _data, _project_name, _built_project, _author, _state) do
    {:error, "Unsupported activity_bank operation '#{action}'"}
  end

  defp normalize_create_attrs(data) do
    with {:ok, content} <- parse_activity_content(data) do
      {:ok,
       %{
         type: data["type"] || data["activity_type_slug"],
         title: data["title"],
         virtual_id: data["virtual_id"],
         content: content,
         objectives: data["objectives"] || [],
         tags: data["tags"] || []
       }}
    end
  end

  defp normalize_bulk_create_attrs(activities) do
    Enum.reduce_while(activities, {:ok, []}, fn data, {:ok, acc} ->
      case normalize_create_attrs(data) do
        {:ok, attrs} -> {:cont, {:ok, [attrs | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, attrs} -> {:ok, Enum.reverse(attrs)}
      error -> error
    end
  end

  defp normalize_update(update, built_project) when is_map(update) do
    update =
      update
      |> normalize_update_content()
      |> normalize_update_objectives(built_project)
      |> normalize_update_tags(built_project)

    case update do
      {:error, reason} -> {:error, reason}
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_update(_update, _built_project), do: {:error, "edit set must be a map"}

  defp normalize_update_content(%{"content" => _content} = update) do
    case parse_activity_content(update) do
      {:ok, content} -> Map.put(update, "content", content)
      error -> error
    end
  end

  defp normalize_update_content(update), do: update

  defp normalize_update_objectives({:error, _} = error, _built_project), do: error

  defp normalize_update_objectives(%{"objectives" => objectives} = update, built_project) do
    case resolve_references(objectives, built_project.objectives_by_title || %{}, "Objective") do
      {:ok, ids} -> Map.put(update, "objectives", ids)
      error -> error
    end
  end

  defp normalize_update_objectives(update, _built_project), do: update

  defp normalize_update_tags({:error, _} = error, _built_project), do: error

  defp normalize_update_tags(%{"tags" => tags} = update, built_project) do
    case resolve_references(tags, built_project.tags_by_title || %{}, "Tag") do
      {:ok, ids} -> Map.put(update, "tags", ids)
      error -> error
    end
  end

  defp normalize_update_tags(update, _built_project), do: update

  defp parse_activity_content(%{"content" => content, "content_format" => "json"}),
    do: {:ok, content}

  defp parse_activity_content(%{"content" => content} = data)
       when is_binary(content) do
    type = data["type"] || data["activity_type_slug"] || "oli_multiple_choice"
    yaml = ensure_activity_type(content, type)

    case ActivityConverter.from_yaml(yaml) do
      {:ok, json} -> {:ok, Map.drop(json, ["type", "objectives", "tags", "title"])}
      {:error, reason} -> {:error, "Failed to parse activity YAML: #{reason}"}
    end
  end

  defp parse_activity_content(%{"content" => content}) when is_map(content), do: {:ok, content}
  defp parse_activity_content(_data), do: {:error, "Activity content is required"}

  defp ensure_activity_type(yaml_content, type) do
    if String.contains?(yaml_content, "type:") do
      yaml_content
    else
      "type: \"#{type}\"\n#{yaml_content}"
    end
  end

  defp query_logic(%{"logic" => logic}, _built_project) when is_map(logic), do: {:ok, logic}

  defp query_logic(%{"filters" => filters}, built_project),
    do: filters_to_logic(filters, built_project)

  defp query_logic(_data, _built_project), do: {:ok, %{"conditions" => nil}}

  defp filters_to_logic(filters, built_project) when is_map(filters) do
    with {:ok, expressions} <- filter_expressions(filters, built_project) do
      conditions =
        case expressions do
          [] -> nil
          [expression] -> expression
          expressions -> %{"operator" => "all", "children" => expressions}
        end

      {:ok, %{"conditions" => conditions}}
    end
  end

  defp filters_to_logic(_filters, _built_project),
    do: {:error, "Activity Bank filters must be a map"}

  defp filter_expressions(filters, built_project) do
    Enum.reduce_while(filters, {:ok, []}, fn {fact, expression}, {:ok, acc} ->
      case filter_expression(fact, expression, built_project) do
        {:ok, nil} -> {:cont, {:ok, acc}}
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, expressions} -> {:ok, Enum.reverse(expressions)}
      error -> error
    end
  end

  defp filter_expression(fact, expression, built_project) when is_map(expression) do
    case Map.to_list(expression) do
      [{operator, value}] ->
        with {:ok, resolved_value} <- resolve_filter_value(fact, value, built_project) do
          {:ok, %{"fact" => fact, "operator" => operator, "value" => resolved_value}}
        end

      _ ->
        {:error, "Activity Bank filter '#{fact}' must specify exactly one operator"}
    end
  end

  defp filter_expression(fact, _expression, _built_project),
    do: {:error, "Activity Bank filter '#{fact}' must be a map"}

  defp resolve_filter_value("tags", value, built_project),
    do: resolve_references(List.wrap(value), built_project.tags_by_title || %{}, "Tag")

  defp resolve_filter_value("objectives", value, built_project),
    do:
      resolve_references(List.wrap(value), built_project.objectives_by_title || %{}, "Objective")

  defp resolve_filter_value("type", value, _built_project) when is_list(value) do
    Enum.reduce_while(value, {:ok, []}, fn type, {:ok, acc} ->
      case resolve_activity_type_value(type) do
        {:ok, id} -> {:cont, {:ok, [id | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, Enum.reverse(ids)}
      error -> error
    end
  end

  defp resolve_filter_value("type", value, _built_project), do: resolve_activity_type_value(value)
  defp resolve_filter_value("text", value, _built_project), do: {:ok, value}

  defp resolve_filter_value(fact, _value, _built_project),
    do: {:error, "Unsupported Activity Bank filter '#{fact}'"}

  defp resolve_activity_type_value(value) when is_integer(value), do: {:ok, value}

  defp resolve_activity_type_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} ->
        {:ok, id}

      _ ->
        case Activities.get_registration_by_slug(value) do
          nil -> {:error, "Unknown activity type: #{value}"}
          registration -> {:ok, registration.id}
        end
    end
  end

  defp resolve_activity_type_value(value),
    do: {:error, "Activity type filter value must be a slug or ID, got: #{inspect(value)}"}

  defp resolve_references(references, title_map, label) when is_list(references) do
    Enum.reduce_while(references, {:ok, []}, fn reference, {:ok, acc} ->
      case resolve_reference(reference, title_map, label) do
        {:ok, id} -> {:cont, {:ok, [id | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, Enum.reverse(ids)}
      error -> error
    end
  end

  defp resolve_references(references, _title_map, label),
    do: {:error, "#{label} references must be a list, got: #{inspect(references)}"}

  defp resolve_reference(value, _title_map, _label) when is_integer(value), do: {:ok, value}

  defp resolve_reference(value, title_map, label) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} ->
        {:ok, id}

      _ ->
        case Map.get(title_map, value) do
          nil -> {:error, "#{label} '#{value}' not found in project"}
          revision -> {:ok, revision.resource_id}
        end
    end
  end

  defp resolve_reference(value, _title_map, label),
    do: {:error, "#{label} reference must be a title or resource ID, got: #{inspect(value)}"}

  defp resolve_activity(%{"resource_id" => resource_id}, _project_name, built_project, _state)
       when is_integer(resource_id) do
    case AuthoringResolver.from_resource_id(built_project.project.slug, resource_id) do
      nil -> {:error, "Activity resource '#{resource_id}' not found"}
      revision -> {:ok, revision}
    end
  end

  defp resolve_activity(%{"virtual_id" => virtual_id}, project_name, _built_project, state) do
    case Map.get(state.activity_virtual_ids, {project_name, virtual_id}) do
      nil -> {:error, "Activity with virtual_id '#{virtual_id}' not found"}
      revision -> {:ok, revision}
    end
  end

  defp resolve_activity(%{"title" => title}, project_name, built_project, state) do
    case Map.get(state.activities, {project_name, title}) do
      nil ->
        case AuthoringResolver.from_title(
               built_project.project.slug,
               title,
               Oli.Resources.ResourceType.id_for_activity()
             ) do
          [revision | _] -> {:ok, revision}
          [] -> {:error, "Activity '#{title}' not found"}
        end

      revision ->
        {:ok, revision}
    end
  end

  defp resolve_activity(_data, _project_name, _built_project, _state),
    do: {:error, "Activity operation requires title, virtual_id, or resource_id"}

  defp duplicate_attrs(revision, data) do
    with {:ok, activity_type_slug} <- activity_type_slug(revision.activity_type_id) do
      {:ok,
       %{
         type: activity_type_slug,
         title: data["new_title"] || "#{revision.title} Copy",
         content: revision.content,
         objectives: objective_ids(revision.objectives),
         tags: revision.tags || []
       }}
    end
  end

  defp activity_type_slug(activity_type_id) do
    case Activities.get_registration(activity_type_id) do
      nil -> {:error, "Unknown activity type id: #{activity_type_id}"}
      registration -> {:ok, registration.slug}
    end
  end

  defp objective_ids(objectives) when is_map(objectives) do
    objectives
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
  end

  defp objective_ids(_objectives), do: []

  defp ensure_activity_lock(project_slug, author, resource_id) do
    case Publishing.project_working_publication(project_slug) do
      nil ->
        {:error, "Working publication not found for project '#{project_slug}'"}

      publication ->
        case Locks.acquire(project_slug, publication.id, resource_id, author.id) do
          {:acquired} -> {:ok, :acquired}
          {:updated} -> {:ok, :updated}
          {:lock_not_acquired, details} -> {:error, {:lock_not_acquired, details}}
          {:error} -> {:error, "Failed to acquire activity lock"}
          {:error, reason} -> {:error, reason}
          other -> {:error, other}
        end
    end
  end

  defp put_activity(state, project_name, revision, title, virtual_id) do
    title = title || revision.title

    state = %{
      state
      | activities: Map.put(state.activities, {project_name, title}, revision)
    }

    if virtual_id do
      %{
        state
        | activity_virtual_ids:
            Map.put(state.activity_virtual_ids, {project_name, virtual_id}, revision)
      }
    else
      state
    end
  end

  defp update_activity(state, project_name, previous_revision, updated_revision, virtual_id) do
    state
    |> remove_activity_title(project_name, previous_revision.title)
    |> put_activity(project_name, updated_revision, updated_revision.title, virtual_id)
  end

  defp remove_activity_title(state, project_name, title) do
    %{state | activities: maybe_delete_key(state.activities, {project_name, title})}
  end

  defp remove_activity(state, project_name, revision, data) do
    activities =
      state.activities
      |> Map.delete({project_name, revision.title})
      |> maybe_delete_key({project_name, data["title"]})

    virtual_ids =
      state.activity_virtual_ids
      |> maybe_delete_key({project_name, data["virtual_id"]})

    %{state | activities: activities, activity_virtual_ids: virtual_ids}
  end

  defp maybe_delete_key(map, {_project_name, nil}), do: map
  defp maybe_delete_key(map, key), do: Map.delete(map, key)

  defp put_query_result(state, nil, _result), do: state

  defp put_query_result(state, name, result) do
    %{state | activity_bank_results: Map.put(state.activity_bank_results, name, result)}
  end

  defp expectation_assertions(nil, _result, _name), do: []

  defp expectation_assertions(expect, %Result{} = result, name) do
    rows = result.rows || []
    titles = Enum.map(rows, & &1.title)
    resource_ids = Enum.map(rows, & &1.resource_id)

    [
      compare_expectation(expect, "total_count", result.totalCount, name),
      compare_expectation(expect, "row_count", result.rowCount, name),
      compare_expectation(expect, "titles", titles, name),
      compare_expectation(expect, "resource_ids", resource_ids, name),
      contains_expectation(expect, "contains_titles", titles, name),
      excludes_expectation(expect, "not_titles", titles, name)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp compare_expectation(expect, key, actual, name) do
    case Map.fetch(expect, key) do
      {:ok, expected} ->
        assertion(name, key, expected == actual, expected, actual)

      :error ->
        nil
    end
  end

  defp contains_expectation(expect, key, actual, name) do
    case Map.fetch(expect, key) do
      {:ok, expected} ->
        missing = expected -- actual
        assertion(name, key, missing == [], expected, actual)

      :error ->
        nil
    end
  end

  defp excludes_expectation(expect, key, actual, name) do
    case Map.fetch(expect, key) do
      {:ok, expected} ->
        actual_set = MapSet.new(actual)
        present = Enum.filter(expected, &MapSet.member?(actual_set, &1))
        assertion(name, key, present == [], expected, actual)

      :error ->
        nil
    end
  end

  defp assertion(result_name, key, passed, expected, actual) do
    %{
      result: result_name,
      key: key,
      passed: passed,
      expected: expected,
      actual: actual
    }
  end

  defp build_verification(project_name, []),
    do: %VerificationResult{
      to: project_name,
      passed: true,
      message: "Activity Bank operations completed"
    }

  defp build_verification(project_name, assertions) do
    failures = Enum.reject(assertions, & &1.passed)

    %VerificationResult{
      to: project_name,
      passed: failures == [],
      message: verification_message(assertions, failures),
      expected: Enum.map(assertions, &Map.take(&1, [:result, :key, :expected])),
      actual: Enum.map(assertions, &Map.take(&1, [:result, :key, :actual, :passed]))
    }
  end

  defp verification_message(_assertions, []), do: "Activity Bank assertions passed"

  defp verification_message(_assertions, failures) do
    "Activity Bank assertions failed: " <>
      Enum.map_join(failures, "; ", fn failure ->
        "#{failure.key} expected #{inspect(failure.expected)}, got #{inspect(failure.actual)}"
      end)
  end

  defp validate_author(nil), do: {:error, "No author available"}
  defp validate_author(author), do: {:ok, author}

  defp validate_project_name(nil), do: {:error, "Project name is required"}
  defp validate_project_name(name) when is_binary(name), do: {:ok, name}
  defp validate_project_name(_), do: {:error, "Project name must be a string"}

  defp get_project(project_name, state) do
    case Map.get(state.projects, project_name) do
      nil -> {:error, "Project '#{project_name}' not found"}
      built_project -> {:ok, built_project}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
