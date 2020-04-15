defmodule Oli.Authoring.Activities do

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Authoring.Activities.{Activity, ActivityFamily, Registration, ActivityRevision}
  alias Oli.Activities.Manifest

  def register_activity(%Manifest{} = manifest) do
    create_registration(%{
      authoring_script: manifest.id <> "-authoring.js",
      authoring_element: manifest.authoring.element,
      delivery_script: manifest.id <> "-delivery.js",
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

  def list_activities do
    Repo.all(Activity)
  end

  def get_activity!(id), do: Repo.get!(Activity, id)

  def create_activity(attrs \\ %{}) do
    %Activity{}
    |> Activity.changeset(attrs)
    |> Repo.insert()
  end

  def new_project_activity(project, family) do
    %Activity{}
      |> Activity.changeset(%{
        project_id: project.id,
        family_id: family.id
      })
  end

  def update_activity(%Activity{} = activity, attrs) do
    activity
    |> Activity.changeset(attrs)
    |> Repo.update()
  end

  def delete_activity(%Activity{} = activity) do
    Repo.delete(activity)
  end

  def change_activity(%Activity{} = activity) do
    Activity.changeset(activity, %{})
  end

  def list_activity_revisions do
    Repo.all(ActivityRevision)
  end

  def get_activity_revision!(id), do: Repo.get!(ActivityRevision, id)

  def create_activity_revision(attrs \\ %{}) do
    %ActivityRevision{}
    |> ActivityRevision.changeset(attrs)
    |> Repo.insert()
  end

  def update_activity_revision(%ActivityRevision{} = activity_revision, attrs) do
    activity_revision
    |> ActivityRevision.changeset(attrs)
    |> Repo.update()
  end

  def delete_activity_revision(%ActivityRevision{} = activity_revision) do
    Repo.delete(activity_revision)
  end

  def change_activity_revision(%ActivityRevision{} = activity_revision) do
    ActivityRevision.changeset(activity_revision, %{})
  end

  def list_activity_registrations do
    Repo.all(Registration)
  end

  def get_registration!(id), do: Repo.get!(Registration, id)

  def create_registration(attrs \\ %{}) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  def update_registration(%Registration{} = registration, attrs) do
    registration
    |> Registration.changeset(attrs)
    |> Repo.update()
  end

  def delete_registration(%Registration{} = registration) do
    Repo.delete(registration)
  end

  def change_registration(%Registration{} = registration) do
    Registration.changeset(registration, %{})
  end
end
