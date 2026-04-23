defmodule Oli.Delivery.Settings.StudentExceptions do
  @moduledoc """
  Delivery-layer operations for assessment settings student exceptions.

  This module is the non-UI boundary for creating, updating, and removing
  per-student assessment setting overrides.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Attempts.AutoSubmit.Worker
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.{AutoSubmitCustodian, StudentException}
  alias Oli.Delivery.Sections
  alias Oli.Repo

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

  @doc """
  Creates a student exception or updates the existing one for the same section,
  resource, and user.
  """
  def set_exception(section, resource_id, user_id, attrs \\ %{}) do
    attrs =
      attrs
      |> normalize_keys()
      |> normalize_late_policy()
      |> normalize_due_date_alias()

    case Settings.get_student_exception(resource_id, section.id, user_id) do
      nil ->
        create_exception(section.id, resource_id, user_id, attrs)

      %StudentException{} = student_exception ->
        update_exception(section, student_exception, attrs)
    end
  end

  @doc """
  Removes a student exception if it exists.
  """
  def remove_exception(section, resource_id, user_id) do
    case Settings.get_student_exception(resource_id, section.id, user_id) do
      nil -> {:ok, nil}
      %StudentException{} = student_exception -> Repo.delete(student_exception)
    end
  end

  @doc """
  Removes all student exceptions for the given users and assessment resource.
  """
  def remove_exceptions(section, resource_id, user_ids) when is_list(user_ids) do
    from(se in StudentException,
      where:
        se.section_id == ^section.id and
          se.resource_id == ^resource_id and
          se.user_id in ^user_ids
    )
    |> Repo.delete_all()
  end

  defp create_exception(section_id, resource_id, user_id, attrs) do
    %StudentException{}
    |> StudentException.changeset(
      Map.merge(attrs, %{
        section_id: section_id,
        resource_id: resource_id,
        user_id: user_id
      })
    )
    |> Repo.insert()
  end

  defp update_exception(section, %StudentException{} = student_exception, attrs) do
    Repo.transaction(fn ->
      maybe_maintain_auto_submit(section, student_exception, attrs)

      student_exception
      |> StudentException.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated_student_exception} -> updated_student_exception
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

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
              error -> Repo.rollback(error)
            end

          not new_needs_auto_submit and not is_nil(attempt.auto_submit_job_id) ->
            case AutoSubmitCustodian.cancel(
                   section.id,
                   student_exception.resource_id,
                   student_exception.user_id
                 ) do
              {:ok, _count} -> :ok
              error -> Repo.rollback(error)
            end

          true ->
            :ok
        end
    end
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
          error -> Repo.rollback(error)
        end
    end
  end
end
