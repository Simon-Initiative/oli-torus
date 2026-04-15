defmodule Oli.Delivery.Settings.StudentExceptions do
  @moduledoc """
  Delivery-layer operations for assessment settings student exceptions.

  This module is the non-UI boundary for creating, updating, and removing
  per-student assessment setting overrides.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.{AutoSubmitCustodian, StudentException}
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
      maybe_adjust_auto_submit(section, student_exception, attrs)

      student_exception
      |> StudentException.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated_student_exception} -> updated_student_exception
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp maybe_adjust_auto_submit(_section, _student_exception, attrs)
       when not is_map_key(attrs, :end_date),
       do: :ok

  defp maybe_adjust_auto_submit(section, student_exception, %{end_date: new_end_date}) do
    if student_exception.late_submit == :disallow do
      case AutoSubmitCustodian.adjust(
             section.id,
             student_exception.resource_id,
             student_exception.end_date,
             new_end_date,
             student_exception.user_id
           ) do
        {:ok, _count} -> :ok
        error -> Repo.rollback(error)
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
    attr = String.to_atom(key)

    if attr in @supported_attrs do
      attr
    else
      raise ArgumentError, "unsupported student exception attribute #{inspect(key)}"
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
end
