defmodule Oli.Delivery.CustomLogs.Utils do
  alias Oli.Delivery.CustomLogs.CustomActivityLog
  alias Oli.Repo

  @doc """
  Creates an activity attempt activity_log.
  ## Examples
      iex> create_activity_log(%{field: value})
      {:ok, %CustomActivityLog{}}
      iex> create_activity_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_activity_log(attrs \\ %{}) do
    IO.inspect "doing the lords work #{inspect attrs}"
    results = %CustomActivityLog{}
    |> CustomActivityLog.changeset(attrs)
    |> Repo.insert()
    IO.inspect "the results #{inspect results}"
    results
  end
end
