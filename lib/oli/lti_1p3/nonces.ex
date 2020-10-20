defmodule Oli.Lti_1p3.Nonces do
  require Logger

  # nonces only persist for a day
  # 86400 seconds = 24 hours
  @max_nonce_ttl_sec 86_400

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Lti_1p3.Nonce

  @doc """
  Gets a single nonce.
  Raises `Ecto.NoResultsError` if the Nonce does not exist.
  ## Examples
      iex> get_nonce!(123)
      %Nonce{}
      iex> get_nonce!(456)
      ** (Ecto.NoResultsError)
  """
  def get_nonce!(id), do: Repo.get!(Nonce, id)

  @doc """
  Creates a nonce. Returns a error if the nonce already exists
  ## Examples
      iex> create_nonce(%{field: value})
      {:ok, %Nonce{}}
      iex> create_nonce(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_nonce(attrs \\ %{}) do
    %Nonce{}
    |> Nonce.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes all nonces older than the configured @max_nonce_ttl_sec value
  """
  def cleanup_nonce_store() do
    Logger.info("Cleaning up expired LTI 1.3 nonces...")

    nonce_expiry = Timex.now |> Timex.subtract(Timex.Duration.from_seconds(@max_nonce_ttl_sec))
    result = Repo.delete_all from(n in Nonce, where: n.inserted_at < ^nonce_expiry)

    Logger.info("done.")

    result
  end

end
