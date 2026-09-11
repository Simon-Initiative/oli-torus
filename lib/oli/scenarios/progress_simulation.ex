defmodule Oli.Scenarios.ProgressSimulation do
  @moduledoc "Runs deterministic learner progress simulation with bounded work and output."

  import Oli.Utils.Seeder.Utils

  alias Oli.Activities
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core.{PartAttempt, StudentInput}
  alias Oli.Delivery.Sections
  alias Oli.Resources.Revision
  alias Oli.Utils.Seeder

  @max_warnings 100
  @supported_activity_types [
    "oli_multiple_choice",
    "oli_ordering",
    "oli_check_all_that_apply",
    "oli_short_answer",
    "oli_multi_input"
  ]

  @spec run(Oli.Delivery.Sections.Section.t(), nil | [Oli.Accounts.User.t()], map()) ::
          {:ok, map()} | {:error, term()}
  def run(section, selected_users, opts) do
    enrolled_users = Sections.fetch_students(section.slug)

    with {:ok, users} <- select_users(selected_users, enrolled_users) do
      pages = Sections.fetch_all_pages(section.slug)
      registrations = activity_registrations()

      outcomes =
        users
        |> Enum.chunk_every(opts.batch_size)
        |> Enum.flat_map(&run_batch(&1, section, pages, registrations, opts))

      {completed, warning_counts} = summarize(outcomes)
      {warnings, warnings_truncated} = structured_warnings(warning_counts)

      {:ok,
       %{
         learners: length(users),
         completed: completed,
         failed: length(users) - completed,
         warnings: warnings,
         warnings_truncated: warnings_truncated
       }}
    end
  end

  defp run_batch(batch, section, pages, registrations, %{max_concurrency: 1} = opts) do
    Enum.map(batch, &{:ok, simulate_user(section, &1, pages, registrations, opts)})
  end

  defp run_batch(batch, section, pages, registrations, opts) do
    Task.async_stream(
      batch,
      &simulate_user(section, &1, pages, registrations, opts),
      max_concurrency: opts.max_concurrency,
      timeout: opts.timeout_ms,
      on_timeout: :kill_task,
      ordered: true
    )
    |> Enum.to_list()
  end

  defp select_users(nil, enrolled_users), do: {:ok, enrolled_users}

  defp select_users(selected_users, enrolled_users) do
    enrolled_ids = MapSet.new(enrolled_users, & &1.id)

    case Enum.reject(selected_users, &MapSet.member?(enrolled_ids, &1.id)) do
      [] -> {:ok, selected_users}
      rejected -> {:error, {:users_not_enrolled_as_learners, Enum.map(rejected, & &1.id)}}
    end
  end

  defp simulate_user(section, user, pages, registrations, opts) do
    session_id = deterministic_session_id(opts.seed, section.id, user.id)
    opts = Map.put(opts, :user_id, user.id)

    Enum.reduce(pages, %{}, fn page, warnings ->
      simulate_page(section, page, user, session_id, registrations, opts, warnings)
    end)
  rescue
    exception -> {:failed, exception}
  end

  defp simulate_page(
         section,
         %Revision{graded: true} = page,
         user,
         session_id,
         registrations,
         opts,
         warnings
       ) do
    map =
      %{scored_page: page, section: section, student: user}
      |> Seeder.Attempt.visit_page(
        ref(:scored_page),
        ref(:section),
        ref(:student),
        session_id,
        page_context_tag: :page_context
      )
      |> Seeder.Attempt.start_scored_assessment(
        ref(:scored_page),
        ref(:section),
        ref(:student),
        session_id,
        resource_attempt_tag: :page_attempt,
        attempt_hierarchy_tag: :page_attempt_hierarchy
      )
      |> Seeder.Attempt.visit_page(
        ref(:scored_page),
        ref(:section),
        ref(:student),
        session_id,
        page_context_tag: :page_context
      )

    {map, warnings} = submit_activities(map, registrations, opts, session_id, warnings)
    Seeder.Attempt.submit_scored_assessment(map, ref(:section), ref(:page_attempt), session_id)
    warnings
  end

  defp simulate_page(section, page, user, session_id, _registrations, _opts, warnings) do
    Seeder.Attempt.visit_page(%{}, page, section, user, session_id)
    warnings
  end

  defp submit_activities(
         %{page_context: %{activities: nil}} = map,
         _registrations,
         _opts,
         _session,
         warnings
       ),
       do: {map, warnings}

  defp submit_activities(
         %{page_context: %{activities: activities, latest_attempts: attempts}} = map,
         registrations,
         opts,
         session_id,
         warnings
       ) do
    Enum.reduce(activities, {map, warnings}, fn {_id, summary}, {acc, warning_acc} ->
      case find_attempt(attempts, summary.attempt_guid) do
        {activity_attempt, part_attempts} ->
          {inputs, new_warnings} =
            part_inputs(activity_attempt, part_attempts, registrations, opts)

          if inputs != [] do
            case Evaluate.evaluate_activity(
                   acc.section.slug,
                   activity_attempt.attempt_guid,
                   inputs,
                   session_id
                 ) do
              {:ok, _result} -> :ok
              {:error, _reason} -> raise "activity evaluation failed"
              _result -> :ok
            end
          end

          {acc, merge_warning_counts(warning_acc, new_warnings)}

        nil ->
          {acc, add_warning(warning_acc, {:missing_attempt, summary.resource_id})}
      end
    end)
  end

  defp submit_activities(map, _registrations, _opts, _session_id, warnings), do: {map, warnings}

  defp find_attempt(attempts, guid) do
    Enum.find_value(attempts, fn
      {_id, {%{attempt_guid: ^guid} = attempt, parts}} -> {attempt, parts}
      _ -> nil
    end)
  end

  defp part_inputs(activity_attempt, parts, registrations, opts) do
    slug = Map.get(registrations, activity_attempt.revision.activity_type_id)

    Enum.reduce(parts, {[], %{}}, fn {_id, %PartAttempt{} = part}, {inputs, warnings} ->
      case response_for_part(slug, part.part_id, activity_attempt.revision, opts) do
        nil ->
          {inputs, add_warning(warnings, {:unsupported_content, slug || "unknown"})}

        input ->
          {[%{part_id: part.part_id, attempt_guid: part.attempt_guid, input: input} | inputs],
           warnings}
      end
    end)
  end

  @doc false
  def response_for_part(slug, part_id, activity, opts)
      when slug in @supported_activity_types do
    with parts when is_list(parts) <- get_in(activity.content, ["authoring", "parts"]),
         part when not is_nil(part) <- Enum.find(parts, &(&1["id"] == part_id)),
         responses when is_list(responses) <- part["responses"] do
      case select_response(
             responses,
             opts.pct_correct,
             {opts.seed, opts.user_id, activity.resource_id, part_id}
           ) do
        nil -> nil
        selection -> %StudentInput{input: selection}
      end
    else
      _ -> nil
    end
  end

  def response_for_part(_slug, _part_id, _activity, _opts), do: nil

  defp parse_rule(rule) when is_binary(rule) do
    patterns = [
      ~r/input (?:like|contains|=) {([^}]+)}/
    ]

    Enum.reduce_while(patterns, "other", fn pattern, fallback ->
      case Regex.run(pattern, rule) do
        [_match, ".*"] -> {:halt, "other"}
        [_match, response] -> {:halt, response}
        _ -> {:cont, fallback}
      end
    end)
  end

  defp parse_rule(_), do: "other"

  @doc false
  def supported_activity_types, do: @supported_activity_types

  @doc false
  def select_response(responses, pct_correct, seed_key) do
    {correct, incorrect} = Enum.split_with(responses, &(&1["score"] > 0))
    prefer_correct? = deterministic_sample({seed_key, :correctness}) < pct_correct

    candidates =
      case {prefer_correct?, correct, incorrect} do
        {true, [_ | _], _} -> correct
        {false, _, [_ | _]} -> incorrect
        {_, [_ | _], []} -> correct
        {_, [], [_ | _]} -> incorrect
        _ -> []
      end

    case candidates do
      [] ->
        nil

      values ->
        index = trunc(deterministic_sample({seed_key, :response}) * length(values))
        values |> Enum.at(index) |> then(&parse_rule(&1["rule"]))
    end
  end

  defp activity_registrations do
    Map.new(Activities.list_activity_registrations(), &{&1.id, &1.slug})
  end

  defp deterministic_session_id(seed, section_id, user_id) do
    UUID.uuid5(:oid, "scenario-progress:#{seed}:#{section_id}:#{user_id}")
  end

  defp deterministic_sample(key), do: :erlang.phash2(key, 1_000_000) / 1_000_000

  defp summarize(outcomes) do
    Enum.reduce(outcomes, {0, %{}}, fn
      {:ok, warnings}, {completed, acc} when is_map(warnings) ->
        {completed + 1, merge_warning_counts(acc, warnings)}

      {:ok, {:failed, reason}}, {completed, acc} ->
        {completed, add_warning(acc, {:learner_failure, failure_category(reason)})}

      {:exit, :timeout}, {completed, acc} ->
        {completed, add_warning(acc, {:learner_timeout, nil})}

      {:exit, reason}, {completed, acc} ->
        {completed, add_warning(acc, {:learner_failure, failure_category(reason)})}
    end)
  end

  defp add_warning(warnings, key), do: Map.update(warnings, key, 1, &(&1 + 1))

  defp merge_warning_counts(left, right) do
    Map.merge(left, right, fn _key, a, b -> a + b end)
  end

  defp structured_warnings(warning_counts) do
    entries = Enum.sort_by(warning_counts, fn {key, _count} -> key end)

    warnings =
      entries
      |> Enum.take(@max_warnings)
      |> Enum.map(fn
        {{:unsupported_content, activity_type}, count} ->
          %{type: :unsupported_content, activity_type: activity_type, count: count}

        {{:missing_attempt, resource_id}, count} ->
          %{type: :missing_attempt, resource_id: resource_id, count: count}

        {{:learner_timeout, nil}, count} ->
          %{type: :learner_timeout, count: count}

        {{:learner_failure, reason}, count} ->
          %{type: :learner_failure, reason: reason, count: count}
      end)

    {warnings, length(entries) > @max_warnings}
  end

  defp failure_category(%{__struct__: module}), do: module |> Module.split() |> List.last()

  defp failure_category(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp failure_category(reason) when is_binary(reason), do: "task_failed"
  defp failure_category(_reason), do: "task_failed"
end
