defmodule Oli.Delivery.Settings.Audited.StudentExceptions do
  @moduledoc false
  # Per-student overrides of an assessment's settings (`delivery_settings` rows).
  #
  # Moved here:
  #   * `Oli.Delivery.Settings.StudentExceptions` (`set_exception/4`, `remove_exception/3`,
  #     `remove_exceptions/3`), whose create and bulk removal ran without a transaction;
  #   * `Oli.Delivery.Settings.update_student_exception/3`, now an update through `set/6`.
  #
  # Creation records `student_exception_created` with the overrides set, an update
  # `student_exception_updated` with the fields that changed, and removal one
  # `student_exception_deleted` per removed row. The student is the affected user.

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Oli.Auditing.{Changes, Command, Context, EntityId}
  alias Oli.Delivery.Attempts.AutoSubmit.Worker
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.{AutoSubmitCustodian, StudentException}
  alias Oli.Delivery.Settings.Audited.Support

  @supported_attrs [
    :start_date,
    :end_date,
    :due_date,
    :max_attempts,
    :late_policy,
    :late_submit,
    :late_start,
    :time_limit,
    :grace_period,
    :scoring_strategy_id,
    :review_submission,
    :feedback_mode,
    :feedback_scheduled_date,
    :retake_mode,
    :assessment_mode,
    :batch_scoring,
    :replacement_strategy,
    :password
  ]

  @supported_attr_by_string Map.new(@supported_attrs, fn attr -> {Atom.to_string(attr), attr} end)

  # Create or update

  def set(%Context{} = context, %Section{} = section, resource_id, user_id, attrs, opts) do
    with {:ok, attrs} <- normalize(attrs) do
      required = Keyword.get(opts, :required, [])

      Command.run(:exception, fn multi ->
        multi
        |> Multi.run(:before, fn _repo, _changes ->
          {:ok, lock(section.id, resource_id, [user_id]) |> List.first()}
        end)
        |> Multi.run(:exception, fn repo, %{before: before} ->
          write(repo, section, before, resource_id, user_id, attrs, required)
        end)
        |> Multi.run(:event, fn _repo, %{before: before, exception: exception} ->
          record(context, [set_proposal(before, exception)])
        end)
      end)
    end
  end

  defp write(repo, section, nil, resource_id, user_id, attrs, required) do
    %StudentException{}
    |> StudentException.changeset(
      Map.merge(attrs, %{section_id: section.id, resource_id: resource_id, user_id: user_id}),
      required
    )
    |> repo.insert()
  end

  defp write(repo, section, %StudentException{} = before, _resource_id, _user_id, attrs, required) do
    with :ok <- maybe_maintain_auto_submit(section, before, attrs) do
      before |> StudentException.changeset(attrs, required) |> repo.update()
    end
  end

  defp set_proposal(nil, exception),
    do: proposal(exception, :created, Changes.diff(nil, overrides(exception), policy()))

  defp set_proposal(before, exception),
    do: proposal(exception, :updated, Changes.diff(before, exception, policy()))

  # Removal

  def remove(%Context{} = context, %Section{} = section, resource_id, user_ids) do
    Command.run(:removed, fn multi ->
      multi
      |> Multi.run(:before, fn _repo, _changes ->
        {:ok, lock(section.id, resource_id, user_ids)}
      end)
      |> Multi.run(:removed, fn repo, %{before: rows} ->
        ids = Enum.map(rows, & &1.id)
        {count, _} = repo.delete_all(from(se in StudentException, where: se.id in ^ids))
        {:ok, count}
      end)
      |> Multi.run(:event, fn _repo, %{before: rows} ->
        record(
          context,
          Enum.map(rows, &proposal(&1, :deleted, Changes.diff(overrides(&1), nil, policy())))
        )
      end)
    end)
  end

  # Reads and events

  # Locks the exceptions of `user_ids` for the assessment, in ID order.
  defp lock(section_id, resource_id, user_ids) do
    from(se in StudentException,
      where:
        se.section_id == ^section_id and se.resource_id == ^resource_id and
          se.user_id in ^user_ids,
      order_by: se.id,
      lock: "FOR UPDATE"
    )
    |> Oli.Repo.all()
  end

  defp record(context, proposals) do
    case Support.record_many(context, proposals) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  defp proposal(%StudentException{} = exception, verb, changes) do
    %{section_id: section_id, resource_id: resource_id, user_id: user_id} = exception

    %{
      event_type: :"student_exception_#{verb}",
      entity:
        {:student_exception,
         EntityId.compose(section: section_id, resource: resource_id, user: user_id), exception},
      scope: %{section_id: section_id, resource_id: resource_id},
      affected: {:user, user_id},
      event_key: "student_exception:#{section_id}:#{resource_id}:#{user_id}:#{verb}",
      changes: changes
    }
  end

  # The overrides an exception sets: the fields with a value.
  defp overrides(%StudentException{} = exception) do
    exception
    |> Map.from_struct()
    |> Map.take(Map.keys(policy()))
    |> Map.reject(fn {_field, value} -> is_nil(value) end)
  end

  defp policy, do: Support.exception_policy()

  # Attribute normalization

  defp normalize(attrs) do
    {:ok,
     attrs
     |> normalize_keys()
     |> normalize_late_policy()
     |> normalize_due_date_alias()}
  rescue
    error in ArgumentError -> {:error, {:invalid_attribute, error.message}}
  end

  defp normalize_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {string_to_supported_attr!(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp string_to_supported_attr!(key) do
    case Map.fetch(@supported_attr_by_string, key) do
      {:ok, attr} -> attr
      :error -> raise ArgumentError, "unsupported student exception attribute #{inspect(key)}"
    end
  end

  defp normalize_due_date_alias(%{due_date: due_date} = attrs) do
    attrs
    |> Map.delete(:due_date)
    |> Map.put(:end_date, due_date)
  end

  defp normalize_due_date_alias(attrs), do: attrs

  defp normalize_late_policy(%{late_policy: policy} = attrs) do
    changes =
      case policy do
        :allow_late_start_and_late_submit ->
          %{late_start: :allow, late_submit: :allow}

        :allow_late_submit_but_not_late_start ->
          %{late_start: :disallow, late_submit: :allow}

        :disallow_late_start_and_late_submit ->
          %{late_start: :disallow, late_submit: :disallow}

        _ ->
          %{}
      end

    attrs
    |> Map.delete(:late_policy)
    |> Map.merge(changes)
  end

  defp normalize_late_policy(attrs), do: attrs

  # Auto-submit maintenance of an update, inside its transaction

  defp maybe_maintain_auto_submit(_section, _student_exception, attrs)
       when not is_map_key(attrs, :end_date) and not is_map_key(attrs, :late_policy) and
              not is_map_key(attrs, :late_submit) and not is_map_key(attrs, :grace_period) and
              not is_map_key(attrs, :time_limit),
       do: :ok

  defp maybe_maintain_auto_submit(section, student_exception, attrs) do
    case active_attempt(section, student_exception) do
      nil ->
        :ok

      attempt ->
        old_settings = Settings.get_combined_settings(attempt)
        new_settings = new_effective_settings(section, student_exception, attempt, attrs)

        old_deadline = Settings.determine_effective_deadline(attempt, old_settings)
        new_deadline = Settings.determine_effective_deadline(attempt, new_settings)

        old_needs_auto_submit = needs_auto_submit?(old_settings, old_deadline)
        new_needs_auto_submit = needs_auto_submit?(new_settings, new_deadline)

        cond do
          new_needs_auto_submit and is_nil(attempt.auto_submit_job_id) ->
            schedule_auto_submit(section, attempt, new_settings)

          new_needs_auto_submit and
              (not old_needs_auto_submit or deadline_changed?(old_deadline, new_deadline)) ->
            case AutoSubmitCustodian.adjust(
                   section.id,
                   student_exception.resource_id,
                   old_deadline || new_deadline,
                   new_deadline,
                   student_exception.user_id
                 ) do
              {:ok, _count} -> :ok
              error -> error
            end

          not new_needs_auto_submit and not is_nil(attempt.auto_submit_job_id) ->
            case AutoSubmitCustodian.cancel(
                   section.id,
                   student_exception.resource_id,
                   student_exception.user_id
                 ) do
              {:ok, _count} -> :ok
              error -> error
            end

          true ->
            :ok
        end
    end
  end

  defp active_attempt(section, student_exception) do
    case Core.get_latest_resource_attempt(
           student_exception.resource_id,
           section.slug,
           student_exception.user_id
         ) do
      %{lifecycle_state: :active} = attempt -> attempt
      _ -> nil
    end
  end

  defp new_effective_settings(section, student_exception, attempt, attrs) do
    updated_exception =
      student_exception
      |> StudentException.changeset(attrs)
      |> Ecto.Changeset.apply_changes()

    section_resource = Sections.get_section_resource(section.id, student_exception.resource_id)

    Settings.combine(attempt.revision, section_resource, updated_exception)
  end

  defp needs_auto_submit?(effective_settings, deadline) do
    effective_settings.late_submit == :disallow and not is_nil(deadline)
  end

  defp deadline_changed?(nil, nil), do: false
  defp deadline_changed?(nil, _), do: true
  defp deadline_changed?(_, nil), do: true

  defp deadline_changed?(old_deadline, new_deadline) do
    DateTime.compare(old_deadline, new_deadline) != :eq
  end

  defp schedule_auto_submit(section, attempt, effective_settings) do
    case Worker.maybe_schedule_auto_submit(effective_settings, section.slug, attempt, nil) do
      {:ok, :not_scheduled} ->
        :ok

      {:ok, auto_submit_job_id} ->
        case Core.update_resource_attempt(attempt, %{auto_submit_job_id: auto_submit_job_id}) do
          {:ok, _attempt} -> :ok
          error -> error
        end
    end
  end
end
