defmodule Oli.ActivitiesTest do
  use Oli.DataCase

  alias Oli.Activities

  describe "activities" do
    alias Oli.Activities.Activity

    @valid_attrs %{slug: "some slug"}
    @update_attrs %{slug: "some updated slug"}
    @invalid_attrs %{slug: nil}

    def activity_fixture(attrs \\ %{}) do
      {:ok, activity} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Activities.create_activity()

      activity
    end

    test "list_activities/0 returns all activities" do
      activity = activity_fixture()
      assert Activities.list_activities() == [activity]
    end

    test "get_activity!/1 returns the activity with given id" do
      activity = activity_fixture()
      assert Activities.get_activity!(activity.id) == activity
    end

    test "create_activity/1 with valid data creates a activity" do
      assert {:ok, %Activity{} = activity} = Activities.create_activity(@valid_attrs)
      assert activity.slug == "some slug"
    end

    test "create_activity/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Activities.create_activity(@invalid_attrs)
    end

    test "update_activity/2 with valid data updates the activity" do
      activity = activity_fixture()
      assert {:ok, %Activity{} = activity} = Activities.update_activity(activity, @update_attrs)
      assert activity.slug == "some updated slug"
    end

    test "update_activity/2 with invalid data returns error changeset" do
      activity = activity_fixture()
      assert {:error, %Ecto.Changeset{}} = Activities.update_activity(activity, @invalid_attrs)
      assert activity == Activities.get_activity!(activity.id)
    end

    test "delete_activity/1 deletes the activity" do
      activity = activity_fixture()
      assert {:ok, %Activity{}} = Activities.delete_activity(activity)
      assert_raise Ecto.NoResultsError, fn -> Activities.get_activity!(activity.id) end
    end

    test "change_activity/1 returns a activity changeset" do
      activity = activity_fixture()
      assert %Ecto.Changeset{} = Activities.change_activity(activity)
    end
  end

  describe "activity_revisions" do
    alias Oli.Activities.ActivityRevision

    @valid_attrs %{content: "some content", deleted: true, slug: "some slug"}
    @update_attrs %{content: "some updated content", deleted: false, slug: "some updated slug"}
    @invalid_attrs %{content: nil, deleted: nil, slug: nil}

    def activity_revision_fixture(attrs \\ %{}) do
      {:ok, activity_revision} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Activities.create_activity_revision()

      activity_revision
    end

    test "list_activity_revisions/0 returns all activity_revisions" do
      activity_revision = activity_revision_fixture()
      assert Activities.list_activity_revisions() == [activity_revision]
    end

    test "get_activity_revision!/1 returns the activity_revision with given id" do
      activity_revision = activity_revision_fixture()
      assert Activities.get_activity_revision!(activity_revision.id) == activity_revision
    end

    test "create_activity_revision/1 with valid data creates a activity_revision" do
      assert {:ok, %ActivityRevision{} = activity_revision} = Activities.create_activity_revision(@valid_attrs)
      assert activity_revision.content == "some content"
      assert activity_revision.deleted == true
      assert activity_revision.slug == "some slug"
    end

    test "create_activity_revision/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Activities.create_activity_revision(@invalid_attrs)
    end

    test "update_activity_revision/2 with valid data updates the activity_revision" do
      activity_revision = activity_revision_fixture()
      assert {:ok, %ActivityRevision{} = activity_revision} = Activities.update_activity_revision(activity_revision, @update_attrs)
      assert activity_revision.content == "some updated content"
      assert activity_revision.deleted == false
      assert activity_revision.slug == "some updated slug"
    end

    test "update_activity_revision/2 with invalid data returns error changeset" do
      activity_revision = activity_revision_fixture()
      assert {:error, %Ecto.Changeset{}} = Activities.update_activity_revision(activity_revision, @invalid_attrs)
      assert activity_revision == Activities.get_activity_revision!(activity_revision.id)
    end

    test "delete_activity_revision/1 deletes the activity_revision" do
      activity_revision = activity_revision_fixture()
      assert {:ok, %ActivityRevision{}} = Activities.delete_activity_revision(activity_revision)
      assert_raise Ecto.NoResultsError, fn -> Activities.get_activity_revision!(activity_revision.id) end
    end

    test "change_activity_revision/1 returns a activity_revision changeset" do
      activity_revision = activity_revision_fixture()
      assert %Ecto.Changeset{} = Activities.change_activity_revision(activity_revision)
    end
  end

  describe "activity_registrations" do
    alias Oli.Activities.Registration

    @valid_attrs %{authoring_script: "some authoring_script", delivery_script: "some delivery_script", description: "some description", element_name: "some element_name", icon: "some icon", title: "some title"}
    @update_attrs %{authoring_script: "some updated authoring_script", delivery_script: "some updated delivery_script", description: "some updated description", element_name: "some updated element_name", icon: "some updated icon", title: "some updated title"}
    @invalid_attrs %{authoring_script: nil, delivery_script: nil, description: nil, element_name: nil, icon: nil, title: nil}

    def registration_fixture(attrs \\ %{}) do
      {:ok, registration} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Activities.create_registration()

      registration
    end

    test "list_activity_registrations/0 returns all activity_registrations" do
      registration = registration_fixture()
      assert Activities.list_activity_registrations() == [registration]
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
      assert registration.element_name == "some element_name"
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
      assert registration.element_name == "some updated element_name"
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
