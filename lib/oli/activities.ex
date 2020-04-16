defmodule Oli.Activities do
  @moduledoc """
  The Activities context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Activities.Activity
  alias Oli.Activities.ActivityFamily
  alias Oli.Activities.Registration
  alias Oli.Activities.Manifest

  def register_activity(%Manifest{} = manifest) do
    create_registration(%{
      authoring_script: manifest.id <> "_authoring.js",
      authoring_element: manifest.authoring.element,
      delivery_script: manifest.id <> "_delivery.js",
      delivery_element: manifest.delivery.element,
      description: manifest.description,
      title: manifest.friendlyName,
      icon: "nothing",
      slug: manifest.id,
    })
  end

  def create_registered_activity_map() do
    list_activity_registrations()
      |> Enum.map(&Oli.Activities.ActivityMapEntry.from_registration/1)
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.slug, e) end)
  end

  def create_activity_family(attrs \\ %{}) do
    %ActivityFamily{}
    |> ActivityFamily.changeset(attrs)
    |> Repo.insert()
  end

  def new_activity_family() do
    %ActivityFamily{}
      |> ActivityFamily.changeset(%{
      })
  end

  def get_registration_by_slug(slug) do
    Repo.one(from p in Registration, where: p.slug == ^slug)
  end

  @doc """
  Returns the list of activities.

  ## Examples

      iex> list_activities()
      [%Activity{}, ...]

  """
  def list_activities do
    Repo.all(Activity)
  end

  @doc """
  Gets a single activity.

  Raises `Ecto.NoResultsError` if the Activity does not exist.

  ## Examples

      iex> get_activity!(123)
      %Activity{}

      iex> get_activity!(456)
      ** (Ecto.NoResultsError)

  """
  def get_activity!(id), do: Repo.get!(Activity, id)

  @doc """
  Creates a activity.

  ## Examples

      iex> create_activity(%{field: value})
      {:ok, %Activity{}}

      iex> create_activity(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_activity(attrs \\ %{}) do
    %Activity{}
    |> Activity.changeset(attrs)
    |> Repo.insert()
  end

  def new_project_activity(project, family) do
    %Activity{}
      |> Activity.changeset(%{
        project_id: project.id, family_id: family.id
      })
  end

  @doc """
  Updates a activity.

  ## Examples

      iex> update_activity(activity, %{field: new_value})
      {:ok, %Activity{}}

      iex> update_activity(activity, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_activity(%Activity{} = activity, attrs) do
    activity
    |> Activity.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a activity.

  ## Examples

      iex> delete_activity(activity)
      {:ok, %Activity{}}

      iex> delete_activity(activity)
      {:error, %Ecto.Changeset{}}

  """
  def delete_activity(%Activity{} = activity) do
    Repo.delete(activity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking activity changes.

  ## Examples

      iex> change_activity(activity)
      %Ecto.Changeset{source: %Activity{}}

  """
  def change_activity(%Activity{} = activity) do
    Activity.changeset(activity, %{})
  end

  alias Oli.Activities.ActivityRevision

  @doc """
  Returns the list of activity_revisions.

  ## Examples

      iex> list_activity_revisions()
      [%ActivityRevision{}, ...]

  """
  def list_activity_revisions do
    Repo.all(ActivityRevision)
  end

  @doc """
  Returns the activity revisions for a list of revision slugs.
  """
  def get_activity_revisions(slugs) do
    Repo.all(from p in ActivityRevision, where: p.slug in ^slugs)
  end

  def get_activity_revision(slug) do
    Repo.one(from p in ActivityRevision, where: p.slug == ^slug) |> Repo.preload([:activity_type])
  end


  @doc """
  Gets a single activity_revision.

  Raises `Ecto.NoResultsError` if the Activity revision does not exist.

  ## Examples

      iex> get_activity_revision!(123)
      %ActivityRevision{}

      iex> get_activity_revision!(456)
      ** (Ecto.NoResultsError)

  """
  def get_activity_revision!(id), do: Repo.get!(ActivityRevision, id)


  @doc """
  Creates a activity_revision.

  ## Examples

      iex> create_activity_revision(%{field: value})
      {:ok, %ActivityRevision{}}

      iex> create_activity_revision(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_activity_revision(attrs \\ %{}) do
    %ActivityRevision{}
    |> ActivityRevision.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a activity_revision.

  ## Examples

      iex> update_activity_revision(activity_revision, %{field: new_value})
      {:ok, %ActivityRevision{}}

      iex> update_activity_revision(activity_revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_activity_revision(%ActivityRevision{} = activity_revision, attrs) do
    activity_revision
    |> ActivityRevision.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a activity_revision.

  ## Examples

      iex> delete_activity_revision(activity_revision)
      {:ok, %ActivityRevision{}}

      iex> delete_activity_revision(activity_revision)
      {:error, %Ecto.Changeset{}}

  """
  def delete_activity_revision(%ActivityRevision{} = activity_revision) do
    Repo.delete(activity_revision)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking activity_revision changes.

  ## Examples

      iex> change_activity_revision(activity_revision)
      %Ecto.Changeset{source: %ActivityRevision{}}

  """
  def change_activity_revision(%ActivityRevision{} = activity_revision) do
    ActivityRevision.changeset(activity_revision, %{})
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
