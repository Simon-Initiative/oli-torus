defmodule Oli.Delivery.Lti do
  @moduledoc """
  The Lti context.
  """

  # nonces only persist for a day
  @max_nonce_ttl_sec 86_400

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Lti.Nonce

  @doc """
  Returns the list of nonce_store.
  ## Examples
      iex> list_nonce_store()
      [%Nonce{}, ...]
  """
  def list_nonce_store do
    Repo.all(Nonce)
  end

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
  Creates a nonce.
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
  Updates a nonce.
  ## Examples
      iex> update_nonce(nonce, %{field: new_value})
      {:ok, %Nonce{}}
      iex> update_nonce(nonce, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_nonce(%Nonce{} = nonce, attrs) do
    nonce
    |> Nonce.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a nonce.
  ## Examples
      iex> delete_nonce(nonce)
      {:ok, %Nonce{}}
      iex> delete_nonce(nonce)
      {:error, %Ecto.Changeset{}}
  """
  def delete_nonce(%Nonce{} = nonce) do
    Repo.delete(nonce)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking nonce changes.
  ## Examples
      iex> change_nonce(nonce)
      %Ecto.Changeset{source: %Nonce{}}
  """
  def change_nonce(%Nonce{} = nonce) do
    Nonce.changeset(nonce, %{})
  end

  def cleanup_nonce_store() do
    # delete all nonces older than configured @max_nonce_ttl_sec
    nonce_expiry = DateTime.add(DateTime.utc_now(), -1 * @max_nonce_ttl_sec, :second)
    from(n in Nonce, where: n.inserted_at < ^nonce_expiry)
    |> Repo.delete_all
  end

  def parse_lti_role(roles) do
    cond do
      String.contains?(roles, "Administrator") ->
        :administrator
      String.contains?(roles, "Instructor") ->
        :instructor
      String.contains?(roles, "Learner") ->
        :student
    end
  end

end
