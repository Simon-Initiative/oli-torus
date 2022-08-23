defmodule Oli.Interop do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Interop.ApiKey

  @doc """
  List all api keys.
  """
  def list_api_keys do
    Repo.all(ApiKey)
  end

  @doc """
  Create a new api key, with the given code and hint.
  """
  def create_key(code, hint) do
    %ApiKey{}
    |> ApiKey.changeset(%{
      hash: :crypto.hash(:md5, code) |> Base.encode16(),
      hint: hint
    })
    |> Repo.insert()
  end

  @doc """
  Retrieve a key by its id.
  """
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

  @doc """
  Creates a changeset for a key.
  """
  def change_key(%ApiKey{} = key) do
    ApiKey.changeset(key, %{})
  end

  @doc """
  Validates that a key can be used for the payments scope.

  Returns true if valid, false if not.
  """
  def validate_for_payments(code) do
    validate(code, :payments_enabled)
  end

  @doc """
  Validates that a key can be used for the products scope.

  Returns true if valid, false if not.
  """
  def validate_for_products(code) do
    validate(code, :products_enabled)
  end

  @doc """
  Validates that a key can be used for the activity registration scope.

  Returns true if valid, false if not.
  """
  def validate_for_registration(code) do
    validate(code, :registration_enabled)
  end

  def validate_for_automation_setup(code) do
    validate(code, :automation_setup_enabled)
  end

  defp validate(code, field) do
    hash = :crypto.hash(:md5, code) |> Base.encode16()

    case Repo.get_by(ApiKey, hash: hash) do
      nil ->
        false

      key ->
        Map.get(key, field) == true and key.status == :enabled
    end
  end

  @doc """
  Returns the registration namespace present in a key.
  """
  def get_namespace(code) do
    hash = :crypto.hash(:md5, code) |> Base.encode16()

    case Repo.get_by(ApiKey, hash: hash) do
      nil -> nil
      key -> Map.get(key, :registration_namespace)
    end
  end
end
