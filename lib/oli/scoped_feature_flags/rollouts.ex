defmodule Oli.ScopedFeatureFlags.Rollouts do
  @moduledoc """
  Persistence and auditing helpers for scoped feature flag rollouts and publisher exemptions.

  This module encapsulates the CRUD operations used by the canary rollout layer,
  ensuring changes are audited, telemetry is emitted, and cache invalidations are broadcast.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Oli.Repo
  alias Oli.ScopedFeatureFlags.ScopedFeatureExemption
  alias Oli.ScopedFeatureFlags.ScopedFeatureRollout

  @pubsub_topic "feature_rollouts"

  @stage_percentages %{
    off: 0,
    internal_only: 0,
    five_percent: 5,
    fifty_percent: 50,
    full: 100
  }

  @type scope_type :: :global | :project | :section

  @doc """
  Returns the current rollout record for the given feature/scope combination.
  """
  @spec get_rollout(String.t() | atom(), scope_type(), integer() | nil) ::
          ScopedFeatureRollout.t() | nil
  def get_rollout(feature_name, scope_type, scope_id \\ nil) do
    feature_name = normalize_feature_name(feature_name)
    scope_type = normalize_scope_type(scope_type)
    scope_id = normalize_scope_id(scope_type, scope_id)

    ScopedFeatureRollout
    |> where([r], r.feature_name == ^feature_name and r.scope_type == ^scope_type)
    |> where(^scope_match_clause(scope_id))
    |> Repo.one()
  end

  @doc """
  Lists all rollout records for a given feature.
  """
  @spec list_rollouts(String.t() | atom()) :: [ScopedFeatureRollout.t()]
  def list_rollouts(feature_name) do
    feature_name = normalize_feature_name(feature_name)

    ScopedFeatureRollout
    |> where([r], r.feature_name == ^feature_name)
    |> order_by([r], asc: r.scope_type, asc_nulls_first: r.scope_id)
    |> Repo.all()
  end

  @doc """
  Retrieves the exemption record for a feature/publisher combination.
  """
  @spec get_exemption(String.t() | atom(), pos_integer()) ::
          ScopedFeatureExemption.t() | nil
  def get_exemption(feature_name, publisher_id) when is_integer(publisher_id) do
    feature_name = normalize_feature_name(feature_name)

    ScopedFeatureExemption
    |> where([e], e.feature_name == ^feature_name and e.publisher_id == ^publisher_id)
    |> Repo.one()
  end

  @doc """
  Lists all exemptions for a given feature.
  """
  @spec list_exemptions(String.t() | atom()) :: [ScopedFeatureExemption.t()]
  def list_exemptions(feature_name) do
    feature_name = normalize_feature_name(feature_name)

    ScopedFeatureExemption
    |> where([e], e.feature_name == ^feature_name)
    |> order_by([e], asc: e.publisher_id)
    |> Repo.all()
    |> Repo.preload([:publisher, :updated_by_author])
  end

  @doc """
  Runs the effects of a committed rollout stage change: telemetry with the previous and new
  stage, cache invalidation, and the PubSub broadcast. `actor_id` is `{:author | :user, id}`.
  """
  def stage_changed(previous, rollout, actor_id) do
    maybe_emit_stage_changed_telemetry(previous, rollout, actor_id)
    broadcast_stage_invalidation(rollout.feature_name, rollout.scope_type, rollout.scope_id)
  end

  @doc "Runs the effects of a committed rollout deletion: cache, PubSub, and telemetry."
  def stage_deleted(rollout, actor_id) do
    broadcast_stage_invalidation(rollout.feature_name, rollout.scope_type, rollout.scope_id)

    :telemetry.execute([:torus, :feature_flag, :rollout_stage_deleted], %{count: 1}, %{
      feature: rollout.feature_name,
      scope_type: rollout.scope_type,
      scope_id: rollout.scope_id,
      stage: rollout.stage,
      actor_id: actor_id
    })
  end

  @doc "Runs the effects of a committed exemption change: cache invalidation and PubSub."
  def exemption_changed(exemption),
    do: broadcast_exemption_invalidation(exemption.feature_name, exemption.publisher_id)

  @doc "Runs the effects of a committed exemption deletion: cache, PubSub, and telemetry."
  def exemption_deleted(exemption, actor_id) do
    broadcast_exemption_invalidation(exemption.feature_name, exemption.publisher_id)

    :telemetry.execute([:torus, :feature_flag, :rollout_exemption_deleted], %{count: 1}, %{
      feature: exemption.feature_name,
      publisher_id: exemption.publisher_id,
      effect: exemption.effect,
      actor_id: actor_id
    })
  end

  @doc "Returns the rollout percentage of `stage`."
  def stage_percentage(stage), do: Map.fetch!(@stage_percentages, stage)

  defp maybe_emit_stage_changed_telemetry(previous, rollout, actor_id) do
    metadata = %{
      feature: rollout.feature_name,
      scope_type: rollout.scope_type,
      scope_id: rollout.scope_id,
      from_stage: previous && previous.stage,
      to_stage: rollout.stage,
      actor_id: actor_id
    }

    :telemetry.execute([:torus, :feature_flag, :rollout_stage_changed], %{count: 1}, metadata)
  end

  defp broadcast_stage_invalidation(feature_name, scope_type, scope_id) do
    Cachex.del(:feature_flag_stage, {:stage, feature_name, scope_type, scope_id})

    Phoenix.PubSub.broadcast(
      Oli.PubSub,
      @pubsub_topic,
      {:stage_invalidated, feature_name, scope_type, scope_id}
    )
  end

  defp broadcast_exemption_invalidation(feature_name, publisher_id) do
    Cachex.del(:feature_flag_stage, {:exemption, feature_name, publisher_id})

    Phoenix.PubSub.broadcast(
      Oli.PubSub,
      @pubsub_topic,
      {:exemption_invalidated, feature_name, publisher_id}
    )
  end

  @doc "Normalizes a feature name to its string form."
  def normalize_feature_name(feature) when is_atom(feature), do: Atom.to_string(feature)
  def normalize_feature_name(feature) when is_binary(feature), do: feature

  @doc "Returns `scope_type` or raises `ArgumentError` when it is not a rollout scope type."
  def normalize_scope_type(scope_type) do
    valid = ScopedFeatureRollout.scope_types()

    if Enum.member?(valid, scope_type) do
      scope_type
    else
      raise ArgumentError,
            "Invalid scope_type #{inspect(scope_type)}. Expected one of #{inspect(valid)}."
    end
  end

  @doc "Returns `stage` or raises `ArgumentError` when it is not a rollout stage."
  def normalize_stage(stage) do
    valid = ScopedFeatureRollout.stages()

    if Enum.member?(valid, stage) do
      stage
    else
      raise ArgumentError,
            "Invalid rollout stage #{inspect(stage)}. Expected one of #{inspect(valid)}."
    end
  end

  @doc "Returns the scope ID for `scope_type` (`nil` for global) or raises `ArgumentError`."
  def normalize_scope_id(:global, _scope_id), do: nil

  def normalize_scope_id(_scope_type, scope_id) when is_integer(scope_id) and scope_id > 0,
    do: scope_id

  def normalize_scope_id(scope_type, scope_id) do
    raise ArgumentError,
          "Invalid scope_id #{inspect(scope_id)} for scope type #{inspect(scope_type)}"
  end

  defp scope_match_clause(nil), do: dynamic([r], is_nil(r.scope_id))
  defp scope_match_clause(scope_id), do: dynamic([r], r.scope_id == ^scope_id)

  @doc "Returns `effect` or raises `ArgumentError` when it is not an exemption effect."
  def normalize_effect(effect) do
    valid = ScopedFeatureExemption.effects()

    if Enum.member?(valid, effect) do
      effect
    else
      raise ArgumentError,
            "Invalid exemption effect #{inspect(effect)}. Expected one of #{inspect(valid)}."
    end
  end
end
