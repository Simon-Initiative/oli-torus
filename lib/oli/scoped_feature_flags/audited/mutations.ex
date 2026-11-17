defmodule Oli.ScopedFeatureFlags.Audited.Mutations do
  @moduledoc false

  # Raw feature flag, rollout, and exemption writes for `Oli.ScopedFeatureFlags.Audited`. They
  # perform no authorization, auditing, or transaction handling; only the audited coordinator
  # may call them.

  import Ecto.Query, only: [from: 2]

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo

  alias Oli.ScopedFeatureFlags.{
    ScopedFeatureExemption,
    ScopedFeatureFlagState,
    ScopedFeatureRollout
  }

  @spec insert_flag(String.t(), struct()) :: {:ok, %ScopedFeatureFlagState{}} | {:error, term()}
  def insert_flag(feature_name, %Project{id: id}) do
    %ScopedFeatureFlagState{}
    |> ScopedFeatureFlagState.changeset_with_project(%{feature_name: feature_name}, id)
    |> Repo.insert()
  end

  def insert_flag(feature_name, %Section{id: id}) do
    %ScopedFeatureFlagState{}
    |> ScopedFeatureFlagState.changeset_with_section(%{feature_name: feature_name}, id)
    |> Repo.insert()
  end

  @spec delete(struct()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def delete(record), do: Repo.delete(record)

  @spec lock_rollout(String.t(), atom(), pos_integer() | nil) :: %ScopedFeatureRollout{} | nil
  def lock_rollout(feature_name, scope_type, scope_id) do
    query =
      case scope_id do
        nil ->
          from(r in ScopedFeatureRollout,
            where:
              r.feature_name == ^feature_name and r.scope_type == ^scope_type and
                is_nil(r.scope_id)
          )

        id ->
          from(r in ScopedFeatureRollout,
            where:
              r.feature_name == ^feature_name and r.scope_type == ^scope_type and
                r.scope_id == ^id
          )
      end

    Repo.one(from(r in query, lock: "FOR UPDATE"))
  end

  @spec put_rollout(%ScopedFeatureRollout{} | nil, map()) ::
          {:ok, %ScopedFeatureRollout{}} | {:error, Ecto.Changeset.t()}
  def put_rollout(existing, attrs) do
    (existing || %ScopedFeatureRollout{})
    |> ScopedFeatureRollout.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @spec lock_exemption(String.t(), pos_integer()) :: %ScopedFeatureExemption{} | nil
  def lock_exemption(feature_name, publisher_id) do
    Repo.one(
      from(e in ScopedFeatureExemption,
        where: e.feature_name == ^feature_name and e.publisher_id == ^publisher_id,
        lock: "FOR UPDATE"
      )
    )
  end

  @spec put_exemption(%ScopedFeatureExemption{} | nil, map()) ::
          {:ok, %ScopedFeatureExemption{}} | {:error, Ecto.Changeset.t()}
  def put_exemption(existing, attrs) do
    (existing || %ScopedFeatureExemption{})
    |> ScopedFeatureExemption.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
