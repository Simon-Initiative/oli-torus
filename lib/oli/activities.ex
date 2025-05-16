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
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment
  import Oli.Utils
  require Logger

  def register_activity(%Manifest{} = manifest, subdirectory \\ "") do
    attrs = %{
      authoring_script: "#{subdirectory}#{manifest.id}_authoring.js",
      authoring_element: manifest.authoring.element,
      delivery_script: "#{subdirectory}#{manifest.id}_delivery.js",
      delivery_element: manifest.delivery.element,
      allow_client_evaluation: manifest.allowClientEvaluation,
      globally_available: manifest.global,
      description: manifest.description,
      title: manifest.friendlyName,
      petite_label: manifest.petiteLabel,
      icon: manifest.icon,
      slug: manifest.id,
      variables: manifest.variables,
      generates_report: manifest.generatesReport
    }

    case get_registration_by_slug(attrs.slug) do
      nil -> create_registration(attrs)
      registration -> update_registration(registration, attrs)
    end
  end

  def register_from_bundle(file, expected_namespace) do
    case :zip.unzip(to_charlist(file), [:memory]) do
      {:ok, entries} ->
        case locate_manifest(entries) |> parse_manifest() do
          {:ok, %Manifest{} = manifest} ->
            if String.starts_with?(manifest.id, "#{expected_namespace}_") do
              process_register_from_bundle(manifest, entries)
            else
              Logger.warning("Invalid namespace")
              {:error, :invalid_namespace}
            end

          e ->
            e
        end

      _ ->
        Logger.warning("Invalid archive")
        {:error, :invalid_archive}
    end
  end

  def register_lti_external_tool_activity(title, petite_label, description) do
    attrs = %{
      slug: Oli.Utils.Slug.slugify(title),
      title: title,
      petite_label: petite_label,
      icon: "plug",
      description: description,
      delivery_element: "lti-external-tool-delivery",
      authoring_element: "lti-external-tool-authoring",
      delivery_script: "lti_external_tool_delivery.js",
      authoring_script: "lti_external_tool_authoring.js",
      allow_client_evaluation: false,
      generates_report: false,
      globally_available: false,
      globally_visible: true,
      variables: []
    }

    case get_registration_by_slug(attrs.slug) do
      nil -> create_registration(attrs)
      registration -> update_registration(registration, attrs)
    end
  end

  defp build_path(path) do
    Application.app_dir(:oli, path)
  end

  defp locate_manifest(entries) do
    case Enum.find(entries, fn {name, _} -> List.to_string(name) == "manifest.json" end) do
      nil -> {nil, %{}}
      manifest -> manifest
    end
  end

  defp parse_manifest({nil, _}) do
    Logger.warning("Missing manifest")
    {:error, :missing_manifest}
  end

  defp parse_manifest({_, content}) do
    case Poison.decode(content) do
      {:ok, json} ->
        Manifest.parse(json)

      e ->
        Logger.warning("Could not parse manifest")
        e
    end
  end

  defp process_register_from_bundle(%Manifest{} = manifest, entries) do
    result =
      case make_dir(manifest) do
        :ok ->
          Enum.reduce_while(entries, {:ok}, fn {file, content}, _ ->
            filename = List.to_string(file)

            case build_path("priv/static/js/#{manifest.id}/#{filename}") |> File.write(content) do
              :ok -> {:cont, {:ok}}
              e -> {:halt, e}
            end
          end)

        e ->
          Logger.warning("Error encountered creating directory")
          e
      end

    case result do
      {:ok} ->
        register_activity(manifest, "#{manifest.id}/")

      e ->
        Logger.warning("Error encountered writing bundle files")
        e
    end
  end

  defp make_dir(%Manifest{} = manifest) do
    case build_path("priv/static/js/#{manifest.id}") |> File.mkdir() do
      :ok -> :ok
      {:error, :eexist} -> :ok
      e -> e
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
      |> Enum.filter(fn a ->
        is_nil(a.status) or a.status == :enabled
      end)
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

  def activities_for_project(project, is_admin? \\ true) do
    project = project |> Repo.preload([:activity_registrations])

    project_activities =
      Enum.reduce(project.activity_registrations, MapSet.new(), fn a, m -> MapSet.put(m, a.id) end)

    activities_enabled =
      list_activity_registrations()
      |> Enum.filter(fn a ->
        (a.globally_visible || is_admin?) and (is_nil(a.status) or a.status == :enabled)
      end)
      |> Enum.reduce([], fn a, m ->
        enabled_for_project =
          a.globally_available === true or MapSet.member?(project_activities, a.id)

        m ++
          [
            %{
              id: a.id,
              authoring_element: a.authoring_element,
              delivery_element: a.delivery_element,
              authoring_script: a.authoring_script,
              delivery_script: a.delivery_script,
              slug: a.slug,
              title: a.title,
              global: a.globally_available,
              petite_label: a.petite_label,
              enabled: enabled_for_project,
              deployment_id: a.deployment_id
            }
          ]
      end)

    Enum.sort_by(activities_enabled, & &1.global, :desc)
  end

  def advanced_activities(project, is_admin? \\ true) do
    activities_for_project(project, is_admin?)
    |> Enum.filter(&(!&1.global))
    |> Enum.sort_by(fn a -> {a.deployment_id, a.title} end)
  end

  # TODO only get needed for section... hide authoring sometimes
  def activities_for_section() do
    Enum.reduce(list_activity_registrations(), [], fn a, m ->
      m ++
        [
          %{
            id: a.id,
            authoring_element: a.authoring_element,
            authoring_script: a.authoring_script,
            delivery_element: a.delivery_element,
            delivery_script: a.delivery_script,
            slug: a.slug,
            title: a.title,
            petite_label: a.petite_label
          }
        ]
    end)
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

  @doc """
  Sets the globally_visible state of a registered activity.  If an activity type
  is globally visible, all authors will see it appear in the list of
  activities within their project.  If an activity type is *not* globally visible,
  it will only appear in that list if the author is also an admin.
  """
  def set_global_visibility(activity_slug, status) do
    with {:ok, activity_registration} <-
           get_registration_by_slug(activity_slug)
           |> trap_nil("An activity with that slug was not found.") do
      update_registration(activity_registration, %{globally_visible: status})
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
    from(ar in ActivityRegistration,
      left_join: d in LtiExternalToolActivityDeployment,
      on: d.activity_registration_id == ar.id,
      select: ar,
      select_merge: %{deployment_id: d.deployment_id, status: d.status}
    )
    |> Repo.all()
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
