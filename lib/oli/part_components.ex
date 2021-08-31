defmodule Oli.PartComponents do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.PartComponents.Manifest
  alias Oli.PartComponents.PartComponentRegistration
  alias Oli.Authoring.Course
  alias Oli.PartComponents.PartComponentRegistrationProject
  alias Oli.PartComponents.PartComponentMapEntry
  import Oli.Utils

  def register_part_component(%Manifest{} = manifest) do
    attrs = %{
      authoring_script: manifest.id <> "_authoring.js",
      authoring_element: manifest.authoring.element,
      delivery_script: manifest.id <> "_delivery.js",
      delivery_element: manifest.delivery.element,
      globally_available: manifest.global,
      description: manifest.description,
      author: manifest.author,
      title: manifest.friendlyName,
      icon: manifest.icon,
      slug: manifest.id
    }

    case get_registration_by_slug(attrs.slug) do
      nil -> create_registration(attrs)
      registration -> update_registration(registration, attrs)
    end
  end

  def create_registered_part_component_map() do
    list_part_component_registrations()
    |> Enum.map(&PartComponentMapEntry.from_registration/1)
    |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.slug, e) end)
  end

  def get_registration_by_slug(slug) do
    Repo.one(from p in PartComponentRegistration, where: p.slug == ^slug)
  end

  @doc """
  Returns the list of part components visible for author to use in particular project.

  ## Examples

      iex> create_registered_part_component_map(philosophy)
      [%PartComponentMapEntry{}, ...]

  """
  @spec create_registered_part_component_map(String.t()) ::
          %PartComponentMapEntry{} | {:error, any}
  def create_registered_part_component_map(project_slug) do
    with {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found.") do
      project = project |> Repo.preload([:part_component_registrations])

      project_part_components =
        Enum.reduce(project.part_component_registrations, MapSet.new(), fn a, m ->
          MapSet.put(m, a.slug)
        end)

      list_part_component_registrations()
      |> Enum.map(&PartComponentMapEntry.from_registration/1)
      |> Enum.reduce(%{}, fn e, m ->
        e =
          if e.globallyAvailable === true or MapSet.member?(project_part_components, e.slug) do
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

  def enable_part_component_in_project(project_slug, part_component_slug) do
    with {:ok, part_component_registration} <-
           get_registration_by_slug(part_component_slug)
           |> trap_nil("An part_component with that slug was not found."),
         {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found.") do
      case Repo.get_by(
             PartComponentRegistrationProject,
             %{
               part_component_registration_id: part_component_registration.id,
               project_id: project.id
             }
           ) do
        nil ->
          %PartComponentRegistrationProject{}
          |> PartComponentRegistrationProject.changeset(%{
            part_component_registration_id: part_component_registration.id,
            project_id: project.id
          })
          |> Repo.insert()

        _ ->
          {:error, "The part_component is already enabled in the project."}
      end
    else
      {:error, {message}} -> {:error, message}
    end
  end

  def disable_part_component_in_project(project_slug, part_component_slug) do
    with {:ok, part_component_registration} <-
           get_registration_by_slug(part_component_slug)
           |> trap_nil("An part_component with that slug was not found."),
         {:ok, project} <-
           Course.get_project_by_slug(project_slug)
           |> trap_nil("The project was not found."),
         {:ok, part_component_project} <-
           Repo.get_by(
             PartComponentRegistrationProject,
             %{
               part_component_registration_id: part_component_registration.id,
               project_id: project.id
             }
           )
           |> trap_nil("The part_component is not enabled on the project.") do
      Repo.delete(part_component_project)
    else
      {:error, {message}} -> {:error, message}
    end
  end

  def part_components_for_project(project) do
    project = project |> Repo.preload([:part_component_registrations])

    project_part_components =
      Enum.reduce(project.part_component_registrations, MapSet.new(), fn a, m ->
        MapSet.put(m, a.id)
      end)

    part_components_enabled =
      Enum.reduce(list_part_component_registrations(), [], fn a, m ->
        enabled_for_project =
          a.globally_available === true or MapSet.member?(project_part_components, a.id)

        m ++
          [
            %{
              slug: a.slug,
              title: a.title,
              icon: a.icon,
              description: a.description,
              author: a.author,
              authoring_element: a.authoring_element,
              authoring_script: a.authoring_script,
              delivery_element: a.delivery_element,
              delivery_script: a.delivery_script,
              global: a.globally_available,
              enabled: enabled_for_project
            }
          ]
      end)

    Enum.sort_by(part_components_enabled, & &1.global, :desc)
  end

  def set_global_status(part_component_slug, status) do
    with {:ok, part_component_registration} <-
           get_registration_by_slug(part_component_slug)
           |> trap_nil("An part_component with that slug was not found.") do
      update_registration(part_component_registration, %{globally_available: status})
    else
      {:error, {message}} -> {:error, message}
    end
  end

  @doc """
  Returns the list of part_component_registrations.

  ## Examples

      iex> list_part_component_registrations()
      [%PartComponentRegistration{}, ...]

  """
  def list_part_component_registrations do
    Repo.all(PartComponentRegistration)
  end

  @doc """
  Returns a list of script urls for all registered parts
  """
  def get_part_component_scripts(scriptType \\ :authoring_script) do
    list_part_component_registrations()
    |> Enum.map(fn r -> Map.get(r, scriptType) end)
  end

  @doc """
  Gets a single registration.

  Raises `Ecto.NoResultsError` if the PartComponentRegistration does not exist.

  ## Examples

      iex> get_registration!(123)
      %PartComponentRegistration{}

      iex> get_registration!(456)
      ** (Ecto.NoResultsError)

  """
  def get_registration!(id), do: Repo.get!(PartComponentRegistration, id)

  def get_registration(id), do: Repo.get(PartComponentRegistration, id)

  @doc """
  Creates a registration.

  ## Examples

      iex> create_registration(%{field: value})
      {:ok, %PartComponentRegistration{}}

      iex> create_registration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_registration(attrs \\ %{}) do
    %PartComponentRegistration{}
    |> PartComponentRegistration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a registration.

  ## Examples

      iex> update_registration(registration, %{field: new_value})
      {:ok, %PartComponentRegistration{}}

      iex> update_registration(registration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_registration(%PartComponentRegistration{} = registration, attrs) do
    registration
    |> PartComponentRegistration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a registration.

  ## Examples

      iex> delete_registration(registration)
      {:ok, %PartComponentRegistration{}}

      iex> delete_registration(registration)
      {:error, %Ecto.Changeset{}}

  """
  def delete_registration(%PartComponentRegistration{} = registration) do
    Repo.delete(registration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking registration changes.

  ## Examples

      iex> change_registration(registration)
      %Ecto.Changeset{source: %PartComponentRegistration{}}

  """
  def change_registration(%PartComponentRegistration{} = registration) do
    PartComponentRegistration.changeset(registration, %{})
  end
end
