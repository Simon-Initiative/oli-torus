defmodule Oli.Activities.ActivityRegistrationProjectTest do
  use Oli.DataCase
  import Oli.Factory
  alias Oli.Activities.ActivityRegistrationProject

  describe "changeset/2" do
    test "requires activity_registration_id" do
      project = insert(:project)

      attrs = %{
        project_id: project.id,
        status: :enabled
      }

      changeset = ActivityRegistrationProject.changeset(%ActivityRegistrationProject{}, attrs)

      refute changeset.valid?
      assert %{activity_registration_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires project_id" do
      activity = insert(:activity_registration)

      attrs = %{
        activity_registration_id: activity.id,
        status: :enabled
      }

      changeset = ActivityRegistrationProject.changeset(%ActivityRegistrationProject{}, attrs)

      refute changeset.valid?
      assert %{project_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "status is optional and defaults to enabled" do
      activity = insert(:activity_registration)
      project = insert(:project)

      attrs = %{
        activity_registration_id: activity.id,
        project_id: project.id
      }

      changeset = ActivityRegistrationProject.changeset(%ActivityRegistrationProject{}, attrs)

      assert changeset.valid?
      # Status should not be in changes since it has a default
      assert get_change(changeset, :status) == nil
    end

    test "validates status enum values" do
      activity = insert(:activity_registration)
      project = insert(:project)

      attrs = %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :invalid_status
      }

      changeset = ActivityRegistrationProject.changeset(%ActivityRegistrationProject{}, attrs)

      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts valid status values" do
      activity = insert(:activity_registration)
      project = insert(:project)

      # Test enabled status
      attrs_enabled = %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :enabled
      }

      changeset_enabled =
        ActivityRegistrationProject.changeset(%ActivityRegistrationProject{}, attrs_enabled)

      assert changeset_enabled.valid?

      # Test disabled status
      attrs_disabled = %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :disabled
      }

      changeset_disabled =
        ActivityRegistrationProject.changeset(%ActivityRegistrationProject{}, attrs_disabled)

      assert changeset_disabled.valid?
    end

    test "enforces unique constraint on activity_registration_id and project_id combination" do
      activity = insert(:activity_registration)
      project = insert(:project)

      # Create first record
      attrs = %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :enabled
      }

      changeset1 = ActivityRegistrationProject.changeset(%ActivityRegistrationProject{}, attrs)
      assert {:ok, _record} = Repo.insert(changeset1)

      # Try to create duplicate
      changeset2 = ActivityRegistrationProject.changeset(%ActivityRegistrationProject{}, attrs)

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert(changeset2)
      end
    end
  end
end
