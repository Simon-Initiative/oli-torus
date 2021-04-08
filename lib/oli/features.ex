defmodule Oli.Features do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Features.{FeatureState, Feature}

  @features [%Feature{id: 1, label: "adaptivity", description: "Adaptive lesson authoring"}]

  @by_id Enum.reduce(@features, %{}, fn f, m -> Map.put(m, f.id, f) end)
  @by_label Enum.reduce(@features, %{}, fn f, m -> Map.put(m, f.label, f) end)

  def features, do: @features

  # By defining these functions like this we get a level of compile time
  # safety since a client could not do something like call get_by_label("something wrong")
  def get_by_id(1), do: Map.get(@by_id, 1)

  def get_by_label("adaptivity"), do: Map.get(@by_label, "adaptivity")

  def enabled?("adaptivity"), do: get_state(get_by_label("adaptivity").id) == :enabled

  defp get_state(id) do
    Repo.get!(FeatureState, id).state
  end

  @doc """
  Returns the list of tuples of features and their states.
  ## Examples
      iex> list_features_and_states()
      [{%Feature{}, state}, ...]
  """
  def list_features_and_states do
    query = from(s in FeatureState, select: s.state, order_by: :id)

    Enum.zip(@features, Repo.all(query))
  end

  def change_state("adaptivity", state),
    do: update_feature_state(get_by_label("adaptivity").id, state)

  def bootstrap_feature_states() do
    Enum.map(@features, fn %Feature{id: id} ->
      case Repo.get(FeatureState, id) do
        nil -> create_feature_state(%{state: :disabled})
        e -> e
      end
    end)
  end

  @doc """
  Creates a feature state.
  """
  def create_feature_state(attrs \\ %{}) do
    %FeatureState{}
    |> FeatureState.changeset(attrs)
    |> Repo.insert()
  end

  defp update_feature_state(id, state) do
    Repo.get!(FeatureState, id)
    |> FeatureState.changeset(%{state: state})
    |> Repo.update()
  end
end
