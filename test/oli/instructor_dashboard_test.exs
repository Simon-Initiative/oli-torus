defmodule Oli.InstructorDashboardTest do
  use Oli.DataCase, async: true

  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.InstructorDashboard
  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Repo

  describe "get_state_by_enrollment_id/1" do
    test "returns nil for invalid or missing enrollment ids" do
      assert InstructorDashboard.get_state_by_enrollment_id("not-an-id") == nil
      assert InstructorDashboard.get_state_by_enrollment_id(-1) == nil
    end

    test "returns the persisted state for an enrollment" do
      enrollment = instructor_enrollment_fixture()

      {:ok, state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:123"
        })

      fetched_state = InstructorDashboard.get_state_by_enrollment_id(enrollment.id)

      assert %InstructorDashboardState{} = fetched_state
      assert fetched_state.id == state.id
    end
  end

  describe "upsert_state/2" do
    test "creates a new instructor dashboard state" do
      enrollment = instructor_enrollment_fixture()

      assert {:ok, state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 last_viewed_scope: "course"
               })

      assert state.enrollment_id == enrollment.id
      assert state.last_viewed_scope == "course"
    end

    test "updates the existing state for the enrollment" do
      enrollment = instructor_enrollment_fixture()

      assert {:ok, original_state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 last_viewed_scope: "course"
               })

      assert {:ok, updated_state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 last_viewed_scope: "container:456"
               })

      assert updated_state.id == original_state.id
      assert updated_state.enrollment_id == enrollment.id
      assert updated_state.last_viewed_scope == "container:456"

      assert Repo.aggregate(InstructorDashboardState, :count, :id) == 1
    end
  end

  defp instructor_enrollment_fixture do
    user = insert(:user)
    section = insert(:section)

    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])
    Sections.get_enrollment(section.slug, user.id, filter_by_status: false)
  end
end
