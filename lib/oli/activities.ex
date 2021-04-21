defmodule Oli.Activities do
  @moduledoc """
  The Activities context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Activities.Manifest
  alias Oli.Activities.ActivityRegistration
  alias Oli.Authoring.Course
  alias Oli.Activities.ActivityRegistrationProject
  alias Oli.Activities.ActivityMapEntry
  import Oli.Utils

  def register_activity(%Manifest{} = manifest) do
    attrs = %{
      authoring_script: manifest.id <> "_authoring.js",
      authoring_element: manifest.authoring.element,
      delivery_script: manifest.id <> "_delivery.js",
      delivery_element: manifest.delivery.element,
      allow_client_evaluation: manifest.allowClientEvaluation,
      globally_available: manifest.global,
      description: manifest.description,
      title: manifest.friendlyName,
      icon: "nothing",
      slug: manifest.id
    }

    case get_registration_by_slug(attrs.slug) do
      nil -> create_registration(attrs)
      registration -> update_registration(registration, attrs)
    end
  end

  def create_registered_activity_map() do
    list_activity_registrations()
    |> Enum.map(&ActivityMapEntry.from_registration/1)
    |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.slug, e) end)
  end

  @doc """
  Returns the list of activities visible for author to use in particular project.

  ## Examples

      iex> create_registered_activity_map(philosophy)
      [%ActivityMapEntry{}, ...]

  """
  @spec create_registered_activity_map(String.t()) :: %ActivityMapEntry{} | {:error, any}
  def create_registered_activity_map(project_slug) do
    with {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found.") do
      project = project |> Repo.preload([:activity_registrations])

      project_activities =
        Enum.reduce(project.activity_registrations, MapSet.new(), fn a, m ->
          MapSet.put(m, a.slug)
        end)

      list_activity_registrations()
      |> Enum.map(&ActivityMapEntry.from_registration/1)
      |> Enum.reduce(%{}, fn e, m ->
        e =
          if e.globallyAvailable === true or MapSet.member?(project_activities, e.slug) do
            Map.merge(e, %{enabledForProject: true})
          else
            e
          end

        Map.put(m, e.slug, e)
      end)
    else
      {:error, {message}} -> {:error, message}
    end
  end

  def enable_activity_in_project(project_slug, activity_slug) do
    with {:ok, activity_registration} <-
           get_registration_by_slug(activity_slug)
           |> trap_nil("An activity with that slug was not found."),
         {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found.") do
      case Repo.get_by(
             ActivityRegistrationProject,
             %{
               activity_registration_id: activity_registration.id,
               project_id: project.id
             }
           ) do
        nil ->
          %ActivityRegistrationProject{}
          |> ActivityRegistrationProject.changeset(%{
            activity_registration_id: activity_registration.id,
            project_id: project.id
          })
          |> Repo.insert()

        _ ->
          {:error, "The activity is already enabled in the project."}
      end
    else
      {:error, {message}} -> {:error, message}
    end
  end

  def disable_activity_in_project(project_slug, activity_slug) do
    with {:ok, activity_registration} <-
           get_registration_by_slug(activity_slug)
           |> trap_nil("An activity with that slug was not found."),
         {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found."),
         {:ok, activity_project} <-
           Repo.get_by(
             ActivityRegistrationProject,
             %{
               activity_registration_id: activity_registration.id,
               project_id: project.id
             }
           )
           |> trap_nil("The activity is not enabled on the project.") do
      Repo.delete(activity_project)
    else
      {:error, {message}} -> {:error, message}
    end
  end

  def activities_for_project(project) do
    project = project |> Repo.preload([:activity_registrations])

    project_activities =
      Enum.reduce(project.activity_registrations, MapSet.new(), fn a, m -> MapSet.put(m, a.id) end)

    activities_enabled =
      Enum.reduce(list_activity_registrations(), [], fn a, m ->
        enabled_for_project =
          a.globally_available === true or MapSet.member?(project_activities, a.id)

        m ++
          [
            %{
              slug: a.slug,
              title: a.title,
              global: a.globally_available,
              enabled: enabled_for_project
            }
          ]
      end)

    Enum.sort_by(activities_enabled, & &1.global, :desc)
  end

  def set_global_status(activity_slug, status) do
    with {:ok, activity_registration} <-
           get_registration_by_slug(activity_slug)
           |> trap_nil("An activity with that slug was not found.") do
      update_registration(activity_registration, %{globally_available: status})
    else
      {:error, {message}} -> {:error, message}
    end
  end

  def get_registration_by_slug(slug) do
    Repo.one(from p in ActivityRegistration, where: p.slug == ^slug)
  end

  @doc """
  Returns the list of activity_registrations.

  ## Examples

      iex> list_activity_registrations()
      [%ActivityRegistration{}, ...]

  """
  def list_activity_registrations do
    Repo.all(ActivityRegistration)
  end

  @doc """
  Returns a list of script urls for all registered activities
  """
  def get_activity_scripts(scriptType \\ :authoring_script) do
    list_activity_registrations()
    |> Enum.map(fn r -> Map.get(r, scriptType) end)
  end

  @doc """
  Gets a single registration.

  Raises `Ecto.NoResultsError` if the ActivityRegistration does not exist.

  ## Examples

      iex> get_registration!(123)
      %ActivityRegistration{}

      iex> get_registration!(456)
      ** (Ecto.NoResultsError)

  """
  def get_registration!(id), do: Repo.get!(ActivityRegistration, id)

  def get_registration(id), do: Repo.get(ActivityRegistration, id)

  @doc """
  Creates a registration.

  ## Examples

      iex> create_registration(%{field: value})
      {:ok, %ActivityRegistration{}}

      iex> create_registration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_registration(attrs \\ %{}) do
    %ActivityRegistration{}
    |> ActivityRegistration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a registration.

  ## Examples

      iex> update_registration(registration, %{field: new_value})
      {:ok, %ActivityRegistration{}}

      iex> update_registration(registration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_registration(%ActivityRegistration{} = registration, attrs) do
    registration
    |> ActivityRegistration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a registration.

  ## Examples

      iex> delete_registration(registration)
      {:ok, %ActivityRegistration{}}

      iex> delete_registration(registration)
      {:error, %Ecto.Changeset{}}

  """
  def delete_registration(%ActivityRegistration{} = registration) do
    Repo.delete(registration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking registration changes.

  ## Examples

      iex> change_registration(registration)
      %Ecto.Changeset{source: %ActivityRegistration{}}

  """
  def change_registration(%ActivityRegistration{} = registration) do
    ActivityRegistration.changeset(registration, %{})
  end
end
