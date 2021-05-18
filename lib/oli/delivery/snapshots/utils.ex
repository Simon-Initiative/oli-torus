defmodule Oli.Delivery.Snapshots.Utils do
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Repo

  @doc """
  Creates a part attempt snapshot.
  ## Examples
      iex> create_snapshot(%{field: value})
      {:ok, %Snapshot{}}
      iex> create_snapshot(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_snapshot(attrs \\ %{}) do
    %Snapshot{}
    |> Snapshot.changeset(attrs)
    |> Repo.insert()
  end
end
