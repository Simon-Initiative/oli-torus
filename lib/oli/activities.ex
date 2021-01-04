defmodule Oli.Activities do
  @moduledoc """
  The Activities context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Activities.Manifest
  alias Oli.Activities.Registration

  def register_activity(%Manifest{} = manifest) do

    attrs = %{
      authoring_script: manifest.id <> "_authoring.js",
      authoring_element: manifest.authoring.element,
      delivery_script: manifest.id <> "_delivery.js",
      delivery_element: manifest.delivery.element,
      description: manifest.description,
      title: manifest.friendlyName,
      icon: "nothing",
      slug: manifest.id,
    }

    case get_registration_by_slug(attrs.slug) do
      nil -> create_registration(attrs)
      registration -> update_registration(registration, attrs)
    end

  end

  def create_registered_activity_map() do
    list_activity_registrations()
      |> Enum.map(&Oli.Activities.ActivityMapEntry.from_registration/1)
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.slug, e) end)
  end

  def get_registration_by_slug(slug) do
    Repo.one(from p in Registration, where: p.slug == ^slug)
  end

  @doc """
  Returns the list of activity_registrations.

  ## Examples

      iex> list_activity_registrations()
      [%Registration{}, ...]

  """
  def list_activity_registrations do
    Repo.all(Registration)
  end

  @doc """
  Returns a list of script urls for all registered activities
  """
  def get_activity_scripts() do
    list_activity_registrations()
      |> Enum.map(fn r -> Map.get(r, :authoring_script) end)
  end

  @doc """
  Gets a single registration.

  Raises `Ecto.NoResultsError` if the Registration does not exist.

  ## Examples

      iex> get_registration!(123)
      %Registration{}

      iex> get_registration!(456)
      ** (Ecto.NoResultsError)

  """
  def get_registration!(id), do: Repo.get!(Registration, id)

  def get_registration(id), do: Repo.get(Registration, id)

  @doc """
  Creates a registration.

  ## Examples

      iex> create_registration(%{field: value})
      {:ok, %Registration{}}

      iex> create_registration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_registration(attrs \\ %{}) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a registration.

  ## Examples

      iex> update_registration(registration, %{field: new_value})
      {:ok, %Registration{}}

      iex> update_registration(registration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_registration(%Registration{} = registration, attrs) do
    registration
    |> Registration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a registration.

  ## Examples

      iex> delete_registration(registration)
      {:ok, %Registration{}}

      iex> delete_registration(registration)
      {:error, %Ecto.Changeset{}}

  """
  def delete_registration(%Registration{} = registration) do
    Repo.delete(registration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking registration changes.

  ## Examples

      iex> change_registration(registration)
      %Ecto.Changeset{source: %Registration{}}

  """
  def change_registration(%Registration{} = registration) do
    Registration.changeset(registration, %{})
  end

end
