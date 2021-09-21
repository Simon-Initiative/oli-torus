defmodule Oli.Interop do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Interop.ApiKey

  def list_api_keys do
    Repo.all(ApiKey)
  end

  def create_key(code, hint) do
    %ApiKey{}
    |> ApiKey.changeset(%{
      hash: :crypto.hash(:md5, code) |> Base.encode16(),
      hint: hint
    })
    |> Repo.insert()
  end

  def get_key(id) do
    Repo.get!(ApiKey, id)
  end

  @doc """
  Updates an api key.
  ## Examples
      iex> update_key(key, %{field: new_value})
      {:ok, %ApiKey{}}
      iex> update_key(key, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_key(%ApiKey{} = key, attrs) do
    key
    |> ApiKey.changeset(attrs)
    |> Repo.update()
  end

  def change_key(%ApiKey{} = key) do
    ApiKey.changeset(key, %{})
  end

  def validate_for_payments(code) do
    validate(code, :payments_enabled)
  end

  def validate_for_products(code) do
    validate(code, :products_enabled)
  end

  defp validate(code, field) do
    hash = :crypto.hash(:md5, code) |> Base.encode16()

    case Repo.get_by(ApiKey, hash: hash) do
      nil -> false
      key -> Map.get(key, field) == true and key.status == :enabled
    end
  end
end
