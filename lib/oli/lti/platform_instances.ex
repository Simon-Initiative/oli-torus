defmodule Oli.Lti.PlatformInstances do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance

  @doc """
  Returns the list of lti_1p3_platform_instances.

  ## Examples

      iex> list_lti_1p3_platform_instance_instances()
      [%PlatformInstance{}, ...]

  """
  def list_lti_1p3_platform_instances do
    Repo.all(PlatformInstance)
  end

  @doc """
  Gets a single platform_instance.

  Raises `Ecto.NoResultsError` if the PlatformInstance does not exist.

  ## Examples

      iex> get_platform_instance!(123)
      %PlatformInstance{}

      iex> get_platform_instance!(456)
      ** (Ecto.NoResultsError)

  """
  def get_platform_instance!(id), do: Repo.get!(PlatformInstance, id)

  @doc """
  Gets a single platform_instance by client id
  ## Examples

      iex> get_platform_instance_by_client_id("123")
      %PlatformInstance{}

      iex> get_platform_instance_by_client_id("456")
      nil

  """
  def get_platform_instance_by_client_id(client_id),
    do: Repo.get_by(PlatformInstance, client_id: client_id)

  @doc """
  Creates a platform_instance.

  ## Examples

      iex> create_platform_instance(%{field: value})
      {:ok, %PlatformInstance{}}

      iex> create_platform_instance(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_platform_instance(attrs \\ %{}) do
    %PlatformInstance{}
    |> PlatformInstance.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a platform_instance.

  ## Examples

      iex> update_platform_instance(platform_instance, %{field: new_value})
      {:ok, %PlatformInstance{}}

      iex> update_platform_instance(platform_instance, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_platform_instance(%PlatformInstance{} = platform_instance, attrs) do
    platform_instance
    |> PlatformInstance.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a platform_instance.

  ## Examples

      iex> delete_platform_instance(platform_instance)
      {:ok, %PlatformInstance{}}

      iex> delete_platform_instance(platform_instance)
      {:error, %Ecto.Changeset{}}

  """
  def delete_platform_instance(%PlatformInstance{} = platform_instance) do
    Repo.delete(platform_instance)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking platform_instance changes.

  ## Examples

      iex> change_platform_instance(platform_instance)
      %Ecto.Changeset{data: %PlatformInstance{}}

  """
  def change_platform_instance(%PlatformInstance{} = platform_instance, attrs \\ %{}) do
    PlatformInstance.changeset(platform_instance, attrs)
  end
end
