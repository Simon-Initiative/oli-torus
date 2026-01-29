defmodule Oli.Features do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Features.{FeatureState, Feature}
  require Logger

  @features [
    %Feature{label: "adaptivity", description: "Adaptive lesson authoring", enabled: true},
    %Feature{
      label: "clickhouse-olap",
      description: "ClickHouse OLAP analytics and admin dashboard access",
      enabled: false
    },
    %Feature{
      label: "clickhouse-olap-bulk-ingest",
      description: "ClickHouse OLAP bulk ingest tooling access",
      enabled: false
    },
    %Feature{label: "equity", description: "Equity qa check", enabled: false},
    %Feature{
      label: "live-debugging",
      description: "Live attempt debugging/observation support",
      enabled: false
    }
  ]

  def features, do: @features

  def enabled?("adaptivity"), do: get_state("adaptivity") == :enabled

  def enabled?("clickhouse-olap"),
    do: clickhouse_olap_enabled?() and get_state("clickhouse-olap") == :enabled

  def enabled?("clickhouse-olap-bulk-ingest"),
    do: clickhouse_olap_enabled?() and get_state("clickhouse-olap-bulk-ingest") == :enabled

  def enabled?("equity"), do: get_state("equity") == :enabled
  def enabled?("live-debugging"), do: get_state("live-debugging") == :enabled

  defp clickhouse_olap_enabled? do
    Application.get_env(:oli, :clickhouse_olap_enabled?, false)
  end

  defp get_state(label) do
    case Repo.get(FeatureState, label) do
      %FeatureState{state: state} ->
        state

      nil ->
        Logger.warning("Feature state missing for #{label}; defaulting to disabled")
        :disabled
    end
  end

  @doc """
  Returns the list of tuples of features and their states.
  ## Examples
      iex> list_features_and_states()
      [{%Feature{}, state}, ...]
  """
  def list_features_and_states do
    states_by_label =
      FeatureState
      |> Repo.all()
      |> Map.new(fn %FeatureState{label: label, state: state} -> {label, state} end)

    Enum.map(@features, fn %Feature{label: label} = feature ->
      {feature, Map.get(states_by_label, label, :disabled)}
    end)
  end

  def change_state(label, state) do
    case Repo.get(FeatureState, label) do
      %FeatureState{} = feature_state ->
        feature_state
        |> FeatureState.changeset(%{state: state})
        |> Repo.update()

      nil ->
        %FeatureState{}
        |> FeatureState.changeset(%{label: label, state: state})
        |> Repo.insert()
    end
  end

  def bootstrap_feature_states() do
    Repo.transaction(fn ->
      # capture existing states
      states_by_label =
        Repo.all(FeatureState)
        |> Enum.reduce(%{}, fn %FeatureState{label: label, state: state}, acc ->
          Map.put_new(acc, label, state)
        end)

      # delete all existing features states
      from(f in FeatureState)
      |> Repo.delete_all()

      # create new feature states, merging with existing states
      feature_states =
        @features
        |> Enum.map(fn %Feature{label: label, enabled: enabled?} ->
          case Map.get(states_by_label, label) do
            nil -> %{label: label, state: if(enabled?, do: :enabled, else: :disabled)}
            state -> %{label: label, state: state}
          end
        end)

      Repo.insert_all(FeatureState, feature_states)
    end)
  end
end
