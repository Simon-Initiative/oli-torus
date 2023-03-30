defmodule Oli.Features do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Features.{FeatureState, Feature}

  @features [
    %Feature{label: "adaptivity", description: "Adaptive lesson authoring"},
    %Feature{label: "equity", description: "Equity qa check"},
    %Feature{label: "live-debugging", description: "Live attempt debugging/observation support"}
  ]

  def features, do: @features

  def enabled?("adaptivity"), do: get_state("adaptivity") == :enabled
  def enabled?("equity"), do: get_state("equity") == :enabled
  def enabled?("live-debugging"), do: get_state("live-debugging") == :enabled

  defp get_state(label) do
    Repo.get!(FeatureState, label).state
  end

  @doc """
  Returns the list of tuples of features and their states.
  ## Examples
      iex> list_features_and_states()
      [{%Feature{}, state}, ...]
  """
  def list_features_and_states do
    query = from(s in FeatureState, select: s.state, order_by: :label)

    Enum.zip(@features, Repo.all(query))
  end

  def change_state(label, state) do
    Repo.get!(FeatureState, label)
    |> FeatureState.changeset(%{state: state})
    |> Repo.update()
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
        |> Enum.map(fn %Feature{label: label} ->
          case Map.get(states_by_label, label) do
            nil -> %{label: label, state: :disabled}
            state -> %{label: label, state: state}
          end
        end)

      Repo.insert_all(FeatureState, feature_states)
    end)
  end
end
