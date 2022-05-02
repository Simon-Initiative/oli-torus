defmodule Oli.Inventories do
  import Ecto.Query, warn: false

  alias Oli.Inventories.Publisher
  alias Oli.Repo

  # ------------------------------------------------------------
  # Publishers

  @doc """
  Returns the list of publishers.

  ## Examples

      iex> list_publishers()
      [%Publisher{}, ...]

  """
  def list_publishers, do: Repo.all(Publisher)

  @doc """
  Creates a publisher.

  ## Examples

      iex> create_publisher(%{field: new_value})
      {:ok, %Publisher{}}

      iex> create_publisher(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_publisher(attrs \\ %{}) do
    %Publisher{}
    |> Publisher.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Finds or creates a publisher.

  ## Examples

      iex> find_or_create_publisher(%{field: value})
      {:ok, %Publisher{}}

      iex> find_or_create_publisher(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def find_or_create_publisher(attrs) do
    case get_publisher_by(%{name: attrs[:name]}) do
      nil ->
        create_publisher(attrs)

      %Publisher{} = publisher ->
        {:ok, publisher}
    end
  end

  def default_publisher_name, do: "Torus Publisher"

  @doc """
  Gets a publisher by id.

  ## Examples

      iex> get_publisher(1)
      %Publisher{}
      iex> get_publisher(123)
      nil
  """
  def get_publisher(id), do: Repo.get(Publisher, id)

  @doc """
  Gets a single publisher by query parameter

  ## Examples

      iex> get_publisher_by(%{name: "example"})
      %Publisher{}
      iex> get_publisher_by(%{name: "bad_name"})
      nil
  """
  def get_publisher_by(clauses), do: Repo.get_by(Publisher, clauses)

  @doc """
  Updates a publisher.

  ## Examples

      iex> update_publisher(publisher, %{name: new_value})
      {:ok, %Publisher{}}
      iex> update_publisher(publisher, %{name: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_publisher(%Publisher{} = publisher, attrs) do
    publisher
    |> Publisher.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a publisher.

  ## Examples

      iex> delete_publisher(publisher)
      {:ok, %Publisher{}}

      iex> delete_publisher(publisher)
      {:error, %Ecto.Changeset{}}

  """
  def delete_publisher(%Publisher{} = publisher) do
    Repo.delete(publisher)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking publisher changes.

  ## Examples

      iex> change_publisher(publisher)
      %Ecto.Changeset{data: %Publisher{}}

  """
  def change_publisher(%Publisher{} = publisher, attrs \\ %{}) do
    Publisher.changeset(publisher, attrs)
  end
end
