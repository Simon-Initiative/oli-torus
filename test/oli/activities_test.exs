defmodule Oli.ActivitiesTest do
  use Oli.DataCase

  alias Oli.Activities

  alias Oli.Accounts.SystemRole
  alias Oli.Accounts.Institution
  alias Oli.Accounts.Author
  alias Oli.Course.Project
  alias Oli.Course.Family
  alias Oli.Publishing.Publication
  alias Oli.Activities.Activity
  alias Oli.Activities.ActivityFamily
  alias Oli.Activities.ActivityRevision
  alias Oli.Activities.Registration

  describe "activities" do
    alias Oli.Activities.Activity

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "tit
      le", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, _publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

      {:ok, activity_family} = ActivityFamily.changeset(%ActivityFamily{}, %{}) |> Repo.insert
      {:ok, activity} = Activity.changeset(%Activity{}, %{project_id: project.id, family_id: activity_family.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :project_id, project.id)

      {:ok, %{activity: activity, valid_attrs: valid_attrs, project: project, family: activity_family}}
    end


    test "list_activities/0 returns all activities", %{activity: activity} do
      assert Activities.list_activities() == [activity]
    end

    test "get_activity!/1 returns the activity with given id", %{activity: activity} do
      assert Activities.get_activity!(activity.id) == activity
    end

    test "new_project_activity/2 with valid data creates a activity", %{project: project, family: family} do
      assert %Ecto.Changeset{valid?: true} = Activities.new_project_activity(project, family)
    end

    test "delete_activity/1 deletes the activity", %{activity: activity} do
      assert {:ok, %Activity{}} = Activities.delete_activity(activity)
      assert_raise Ecto.NoResultsError, fn -> Activities.get_activity!(activity.id) end
    end

    test "change_activity/1 returns a activity changeset", %{activity: activity} do
      assert %Ecto.Changeset{} = Activities.change_activity(activity)
    end
  end

  describe "activity_revisions" do
    alias Oli.Activities.ActivityRevision

    @valid_attrs %{content: %{}, objectives: %{}, deleted: true, title: "some slug"}
    @update_attrs %{content: %{"test" => "ok"}, objectives: %{}, deleted: false, title: "test"}
    @invalid_attrs %{content: nil, deleted: nil, slug: nil}


    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, _publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

      {:ok, activity_family} = ActivityFamily.changeset(%ActivityFamily{}, %{}) |> Repo.insert
      {:ok, activity} = Activity.changeset(%Activity{}, %{project_id: project.id, family_id: activity_family.id}) |> Repo.insert
      {:ok, activity_type} = Registration.changeset(%Registration{}, %{slug: "slug", authoring_script: "1", delivery_script: "2", description: "d", authoring_element: "n", delivery_element: "n", icon: "i", title: "t"}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :project_id, project.id)
        |> Map.put(:author_id, author.id)
        |> Map.put(:activity_id, activity.id)
        |> Map.put(:previous_revision_id, nil)
        |> Map.put(:activity_type_id, activity_type.id)

      {:ok, revision} = Activities.create_activity_revision(valid_attrs)

      {:ok, %{activity_revision: revision, valid_attrs: valid_attrs}}
    end


    test "list_activity_revisions/0 returns all activity_revisions", %{activity_revision: activity_revision} do
      assert Activities.list_activity_revisions() == [activity_revision]
    end

    test "get_activity_revision!/1 returns the activity_revision with given id", %{activity_revision: activity_revision} do
      assert Activities.get_activity_revision!(activity_revision.id) == activity_revision
    end

    test "create_activity_revision/1 with valid data creates a activity_revision", %{valid_attrs: valid_attrs} do

      assert {:ok, %ActivityRevision{} = activity_revision} = Activities.create_activity_revision(valid_attrs)
      assert activity_revision.content == %{}
      assert activity_revision.deleted == true
      assert activity_revision.slug != "some_slug"
    end

    test "create_activity_revision/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Activities.create_activity_revision(@invalid_attrs)
    end

    test "update_activity_revision/2 with valid data updates the activity_revision", %{activity_revision: activity_revision} do
      assert {:ok, %ActivityRevision{} = activity_revision} = Activities.update_activity_revision(activity_revision, @update_attrs)
      assert activity_revision.content == %{"test" => "ok"}
      assert activity_revision.deleted == false
      assert activity_revision.slug == "test"
    end

    test "update_activity_revision/2 with invalid data returns error changeset", %{activity_revision: activity_revision} do
      assert {:error, %Ecto.Changeset{}} = Activities.update_activity_revision(activity_revision, @invalid_attrs)
      assert activity_revision == Activities.get_activity_revision!(activity_revision.id)
    end

    test "delete_activity_revision/1 deletes the activity_revision", %{activity_revision: activity_revision} do
      assert {:ok, %ActivityRevision{}} = Activities.delete_activity_revision(activity_revision)
      assert_raise Ecto.NoResultsError, fn -> Activities.get_activity_revision!(activity_revision.id) end
    end

    test "change_activity_revision/1 returns a activity_revision changeset", %{activity_revision: activity_revision} do
      assert %Ecto.Changeset{} = Activities.change_activity_revision(activity_revision)
    end
  end

  describe "activity_registrations" do
    alias Oli.Activities.Registration

    @valid_attrs %{slug: "slug", authoring_script: "some authoring_script", delivery_script: "some delivery_script", description: "some description", delivery_element: "some element_name", authoring_element: "some element_name", icon: "some icon", title: "some title"}
    @update_attrs %{slug: "slug", authoring_script: "some updated authoring_script", delivery_script: "some updated delivery_script", description: "some updated description", delivery_element: "some updated element_name", authoring_element: "some updated element_name", icon: "some updated icon", title: "some updated title"}
    @invalid_attrs %{slug: nil, authoring_script: nil, delivery_script: nil, description: nil, element_name: nil, icon: nil, title: nil}

    def registration_fixture(attrs \\ %{}) do
      {:ok, registration} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Activities.create_registration()

      registration
    end

    test "list_activity_registrations/0 returns all activity_registrations" do
      registration_fixture()
      registrations = Activities.list_activity_registrations()
      assert length(registrations) == 2
    end

    test "get_registration!/1 returns the registration with given id" do
      registration = registration_fixture()
      assert Activities.get_registration!(registration.id) == registration
    end

    test "create_registration/1 with valid data creates a registration" do
      assert {:ok, %Registration{} = registration} = Activities.create_registration(@valid_attrs)
      assert registration.authoring_script == "some authoring_script"
      assert registration.delivery_script == "some delivery_script"
      assert registration.description == "some description"
      assert registration.authoring_element == "some element_name"
      assert registration.icon == "some icon"
      assert registration.title == "some title"
    end

    test "create_registration/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Activities.create_registration(@invalid_attrs)
    end

    test "update_registration/2 with valid data updates the registration" do
      registration = registration_fixture()
      assert {:ok, %Registration{} = registration} = Activities.update_registration(registration, @update_attrs)
      assert registration.authoring_script == "some updated authoring_script"
      assert registration.delivery_script == "some updated delivery_script"
      assert registration.description == "some updated description"
      assert registration.authoring_element == "some updated element_name"
      assert registration.icon == "some updated icon"
      assert registration.title == "some updated title"
    end

    test "update_registration/2 with invalid data returns error changeset" do
      registration = registration_fixture()
      assert {:error, %Ecto.Changeset{}} = Activities.update_registration(registration, @invalid_attrs)
      assert registration == Activities.get_registration!(registration.id)
    end

    test "delete_registration/1 deletes the registration" do
      registration = registration_fixture()
      assert {:ok, %Registration{}} = Activities.delete_registration(registration)
      assert_raise Ecto.NoResultsError, fn -> Activities.get_registration!(registration.id) end
    end

    test "change_registration/1 returns a registration changeset" do
      registration = registration_fixture()
      assert %Ecto.Changeset{} = Activities.change_registration(registration)
    end
  end
end
