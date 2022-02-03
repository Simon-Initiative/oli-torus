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
    %CustomActivityLog{}
    |> CustomActivityLog.changeset(attrs)
    |> Repo.insert()
  end
end
