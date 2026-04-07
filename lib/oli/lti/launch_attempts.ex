defmodule Oli.Lti.LaunchAttempts do
  @moduledoc """
  Domain API for database-backed LTI launch attempts.
  """

  import Ecto.Query, warn: false

  alias Oli.Lti.LaunchAttempt
  alias Oli.Repo

  require Logger

  @default_ttl_seconds 600
  @telemetry_prefix [:oli, :lti, :launch_attempt]

  @type resolve_error :: :not_found | :expired | :consumed

  @spec create_launch_attempt(map()) :: {:ok, LaunchAttempt.t()} | {:error, Ecto.Changeset.t()}
  def create_launch_attempt(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{})
      |> Map.put_new(:state_token, UUID.uuid4())
      |> Map.put_new(:nonce, UUID.uuid4())
      |> Map.put_new(:lifecycle_state, :pending_launch)
      |> Map.put_new(:roles, [])
      |> Map.put_new(:launch_presentation, %{})
      |> Map.put_new(:expires_at, expires_at())

    %LaunchAttempt{}
    |> LaunchAttempt.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, attempt} ->
        log(:info, "Created LTI launch attempt", attempt)
        emit(:created, attempt)
        {:ok, attempt}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @spec get_attempt_by_state_token(String.t()) :: LaunchAttempt.t() | nil
  def get_attempt_by_state_token(state_token) when is_binary(state_token) do
    Repo.get_by(LaunchAttempt, state_token: state_token)
  end

  @spec resolve_active_attempt(String.t()) :: {:ok, LaunchAttempt.t()} | {:error, resolve_error()}
  def resolve_active_attempt(state_token) when is_binary(state_token) do
    case get_attempt_by_state_token(state_token) do
      nil ->
        {:error, :not_found}

      %LaunchAttempt{} = attempt ->
        cond do
          attempt.lifecycle_state == :expired ->
            {:error, :expired}

          attempt.lifecycle_state in LaunchAttempt.active_lifecycle_states() and expired?(attempt) ->
            case transition_attempt(
                   attempt.id,
                   attempt.lifecycle_state,
                   :expired,
                   %{failure_classification: :expired_state}
                 ) do
              {:ok, _attempt} -> {:error, :expired}
              {:error, :transition_conflict} -> {:error, :expired}
              {:error, _changeset} -> {:error, :expired}
            end

          attempt.lifecycle_state in LaunchAttempt.active_lifecycle_states() ->
            {:ok, attempt}

          true ->
            {:error, :consumed}
        end
    end
  end

  @spec transition_attempt(integer(), atom(), atom(), map()) ::
          {:ok, LaunchAttempt.t()} | {:error, :transition_conflict | Ecto.Changeset.t()}
  def transition_attempt(id, from_state, to_state, attrs \\ %{})
      when is_integer(id) and is_atom(from_state) and is_atom(to_state) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      attrs
      |> Enum.into(%{})
      |> normalize_transition_attrs(to_state, now)

    query =
      from(launch_attempt in LaunchAttempt,
        where: launch_attempt.id == ^id and launch_attempt.lifecycle_state == ^from_state
      )

    case Repo.one(query) do
      nil ->
        {:error, :transition_conflict}

      %LaunchAttempt{} = attempt ->
        case attempt
             |> LaunchAttempt.changeset(Map.put(attrs, :lifecycle_state, to_state))
             |> Repo.update() do
          {:ok, updated_attempt} ->
            log(:info, "Transitioned LTI launch attempt", updated_attempt,
              from_state: from_state,
              to_state: to_state
            )

            emit(:transitioned, updated_attempt, %{from_state: from_state, to_state: to_state})
            {:ok, updated_attempt}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @spec cleanup_expired() :: {:ok, non_neg_integer()}
  def cleanup_expired do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      from(launch_attempt in LaunchAttempt,
        where:
          launch_attempt.lifecycle_state in ^LaunchAttempt.cleanup_lifecycle_states() and
            launch_attempt.expires_at <= ^now
      )
      |> Repo.delete_all()

    Logger.info("Cleaned up expired LTI launch attempts count=#{count}")
    :telemetry.execute(@telemetry_prefix ++ [:cleanup], %{count: count}, %{result: :ok})

    {:ok, count}
  end

  defp expires_at do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.add(@default_ttl_seconds, :second)
  end

  defp expired?(%LaunchAttempt{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now() |> DateTime.truncate(:second), expires_at) in [:gt, :eq]
  end

  defp normalize_transition_attrs(attrs, to_state, now) do
    attrs
    |> Map.put_new(:consumed_at, consumed_at_for_state(to_state, now))
    |> Map.put_new(:launched_at, launched_at_for_state(to_state, now))
    |> Map.put_new(:failure_classification, failure_classification_for_state(to_state))
  end

  defp consumed_at_for_state(to_state, now)
       when to_state in [:launch_succeeded, :launch_failed, :registration_handoff, :expired],
       do: now

  defp consumed_at_for_state(_to_state, _now), do: nil

  defp launched_at_for_state(:launching, now), do: now
  defp launched_at_for_state(_to_state, _now), do: nil

  defp failure_classification_for_state(:expired), do: :expired_state
  defp failure_classification_for_state(_to_state), do: nil

  defp emit(event, %LaunchAttempt{} = attempt, extra_meta \\ %{}) do
    :telemetry.execute(
      @telemetry_prefix ++ [event],
      %{count: 1},
      %{
        attempt_id: attempt.id,
        flow_mode: attempt.flow_mode,
        transport_method: attempt.transport_method,
        lifecycle_state: attempt.lifecycle_state,
        failure_classification: attempt.failure_classification
      }
      |> Map.merge(Enum.into(extra_meta, %{}))
    )
  end

  defp log(level, message, %LaunchAttempt{} = attempt, extra_meta \\ %{}) do
    metadata =
      %{
        attempt_id: attempt.id,
        flow_mode: attempt.flow_mode,
        transport_method: attempt.transport_method,
        lifecycle_state: attempt.lifecycle_state,
        failure_classification: attempt.failure_classification
      }
      |> Map.merge(Enum.into(extra_meta, %{}))

    Logger.log(level, fn -> "#{message} #{format_metadata(metadata)}" end)
  end

  defp format_metadata(metadata) do
    metadata
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map_join(" ", fn {key, value} -> "#{key}=#{value}" end)
  end
end
